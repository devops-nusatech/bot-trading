# frozen_string_literal: true

module Bot::Exchange
  class Nusabot < Base
    # Takes config (hash), strategy(+Bot::Strategy+ instance)
    # * +strategy+ is setted in +super+
    # * creates @connection for RestApi
    attr_accessor :orderbook

    def initialize(config)
      super
      @exchange_route = config["exchange_route"] || "exchange"
      @account_route = config["account_route"] || "account"
      @ranger_route = config["ranger_route"] || "ranger"
      @finex_route = config["finex_route"] || "finex"
      @finex = config["finex"] == true
      @ws_base_url = config["ws"] ||= "wss://%s" % [URI.parse(config["host"]).hostname]

      @connection = Faraday.new(url: "#{config['host']}/api/v2") do |conn|
        conn.options.timeout = 10
        conn.response :json
        conn.response :logger if @debug
        conn.adapter(@adapter)
        conn.ssl[:verify] = false unless @verify_ssl
      end
      apply_flags(FORCE_MARKET_LOWERCASE)
    end

    def ws_connect(ws_id)
      streams = []

      case ws_id
      when :public
        streams = ["global.tickers"]
      when :private
        streams = %w[order trade]
        streams << "balances" if @finex
      else
        raise "ACCOUNT:#{id} Unexpected websocket id #{ws_id}"
      end

      if flag?(LISTEN_PUBLIC_ORDERBOOK) && !@markets_to_listen.empty?
        @markets_to_listen.each do |id|
          streams << "#{id}.ob-inc"
        end
      end

      @ws_url = "%s/api/v2/%s/%s/?%s" % [@ws_base_url, @ranger_route, ws_id.to_s, streams.map {|s| "stream=#{s}" }.join("&")]

      unless @ping_fiber
        @ping_fiber = Fiber.new do
          EM::Synchrony.add_periodic_timer(53) do
            ws_write_message(ws_id, "ping")
          end
        end
        @ping_fiber.resume
      end

      super(ws_id)
    end

    def account_infos
      get "#{@account_route}/resource/users/me"
    end

    def cancel_all_orders(market)
      post(
        "#{@finex ? @finex_route : @exchange_route}/market/orders/cancel",
        market: market.to_s.downcase
      )
    end

    # Takes +order+ (+Bot::Order+ instance)
    # * creates +order+ via RestApi
    def create_order(order)
      raise "ACCOUNT:#{id} amount_s is nil" if order.amount_s.nil?
      raise "ACCOUNT:#{id} price_s is nil" if order.price_s.nil? && order.type == "limit"

      params = @finex ? {
        market: order.market.downcase,
        side:   order.side.to_s,
        amount: order.amount_s,
        price:  order.price_s,
        type:   order.type,
      } : {
        market:   order.market.downcase,
        side:     order.side.to_s,
        volume:   order.amount_s,
        price:    order.price_s,
        ord_type: order.type,
      }
      params.delete(:price) if order.type == "market"
      response = post("#{@finex ? @finex_route : @exchange_route}/market/orders", params)

      if response.status >= 300
        logger.warn { "ACCOUNT:#{id} Failed to create order #{order} status:#{response.status}(#{response.reason_phrase}) body:#{response.body}" }
      end

      if order.type == "limit" && response.env.status == 201 && response.env.body["id"] && response.env.body["id"] != 0
        order.id = response.env.body["id"]
      end
      order
    end

    # Takes +order+ (+Bot::Order+ instance)
    # * cancels +order+ via RestApi
    def stop_order(order)
      raise "Trying to cancel an order without id #{order}" if order.id.nil? || order.id == 0

      req = "#{@exchange_route}/market/orders/#{order.id}/cancel"
      req = "#{@finex_route}/market/orders/cancel/#{order.id}" if @finex

      response = post(req)
      return unless response.body&.is_a?(Hash)

      if response.body["error"] == "order is already closed"
        notify_deleted_order(order)
        logger.warn { "ACCOUNT:#{id} order #{order.id} was already closed" }
        return
      end

      raise response.body["error"].to_s if response.body["error"]
      raise response.body["errors"].to_s if response.body["errors"]
      return unless %w[cancel rejected done].include?(response.body["state"])

      logger.warn { "ACCOUNT:#{id} order #{order.id} was #{response.body['state']}" }
      notify_deleted_order(order)
    end

    def get_balances
      response = get("#{@exchange_route}/account/balances")
      raise response.body.to_s if response.status != 200

      response.body.map do |data|
        {
          "currency" => data["currency"],
          "free"     => data["balance"].to_f,
          "locked"   => data["locked"].to_f,
          "total"    => data["balance"].to_f + data["locked"].to_f,
        }
      end
    end

    def currencies
      get("#{@exchange_route}/public/currencies").body
    end

    def get_deposit_address(currency)
      get("#{@exchange_route}/account/deposit_address/#{currency}").body
    end

    def fetch_openorders(market)
      orders = []
      limit = 1000
      page = 1
      loop do
        resp = get("#{@exchange_route}/market/orders", market: market.to_s.downcase, limit: limit, page: page, state: "wait")
        if resp.body.is_a?(Hash) && resp.body["errors"]
          raise resp.body["errors"].to_s
        end
        resp.body&.each do |o|
          order = Bot::Order.new(o["market"].upcase, o["price"].to_f, o["remaining_volume"].to_f, o["side"].to_sym)
          order.id = o["id"]
          orders << order
        end

        raise "ACCOUNT:#{id} Bad response when fetching open orders" if resp.body.nil?
        break if resp.body.size < limit
        if page == 10
          logger.warn "More than #{orders.size} orders in result, stopping"
          break
        end
        page += 1
      end
      orders
    end

    def create_or_update_orderbook(orderbook, snapshot)
      (snapshot["bids"] || []).each do |price, amount|
        amount = amount.to_d
        if amount == 0
          orderbook[:buy].delete(price.to_d)
        else
          orderbook.update_amount(:buy, price.to_d, amount)
        end
      end
      (snapshot["asks"] || []).each do |price, amount|
        amount = amount.to_d
        if amount == 0
          orderbook[:sell].delete(price.to_d)
        else
          orderbook.update_amount(:sell, price.to_d, amount)
        end
      end
      orderbook
    end

    def update_orderbook(market)
      return @books[market][:book] if @books[market]

      limit = @opts["limit"] || 1000
      snapshot = @connection.get("#{@exchange_route}/public/markets/#{market.downcase}/depth", limit: limit).body
      create_or_update_orderbook(Bot::Orderbook::Orderbook.new(market), snapshot)
    end

    def get_market_infos(market)
      @market_infos ||= @connection.get("#{@finex ? @finex_route : @exchange_route}/public/markets").body
      infos = @market_infos&.select {|m| m["id"]&.downcase == market.downcase }&.first
      raise "Market #{market} not found" unless infos

      infos
    end

    def market_config(market)
      market_infos = get_market_infos(market)
      base_unit = market_infos["ask_unit"] || market_infos.fetch("base_unit")
      quote_unit = market_infos["bid_unit"] || market_infos.fetch("quote_unit")
      amount_precision = market_infos["ask_precision"] || market_infos.fetch("amount_precision")
      price_precision = market_infos["bid_precision"] || market_infos.fetch("price_precision")
      {
        "id"               => market_infos.fetch("id"),
        "base_unit"        => base_unit,
        "quote_unit"       => quote_unit,
        "min_price"        => (market_infos["min_price"] || market_infos["min_ask_price"])&.to_f,
        "max_price"        => (market_infos["max_price"] || market_infos["max_bid_price"])&.to_f,
        "min_amount"       => (market_infos["min_amount"] || market_infos["min_ask_amount"] || market_infos["min_bid_amount"])&.to_f,
        "amount_precision" => amount_precision,
        "price_precision"  => price_precision
      }
    end

    def generate_headers
      nonce = (Time.now.to_f * 1000).to_i.to_s
      {
        "X-Auth-Apikey"    => @api_key,
        "X-Auth-Nonce"     => nonce,
        "X-Auth-Signature" => OpenSSL::HMAC.hexdigest("SHA256", @secret, nonce + @api_key),
        "Content-Type"     => "application/json",
      }
    end

    private

    # Helper method to perform post requests
    # * takes +conn+ - faraday connection
    # * takes +path+ - request url
    # * takes +params+ - body for +POST+ request
    def post(path, params=nil)
      logger.info { "ACCOUNT:#{id} POST: #{path} PARAMS: #{params}" } if @debug
      response = @connection.post do |req|
        req.headers = generate_headers
        req.url path
        req.body = params.to_json
      end
      response
    end

    def delete(path, params=nil)
      logger.info { "ACCOUNT:#{id} DELETE: #{path} PARAMS: #{params}" } if @debug
      response = @connection.delete do |req|
        req.headers = generate_headers
        req.url path
        req.body = params.to_json
      end
      response
    end

    def get(path, params=nil)
      response = @connection.get do |req|
        req.headers = generate_headers
        req.url path, params
      end
      response
    end

    # Helper method, generates headers to authenticate with +api_key+

    def side_from_kind(kind)
      kind == "bid" ? :buy : :sell
    end

    def ws_read_message(ws_id, msg)
      return if msg.data == "pong"

      super
    end

    def ws_read_public_message(msg)
      msg.each do |key, content|
        case key
        when /([^.]+)\.ob-snap/
          market_id = Regexp.last_match(1)
          @books[market_id] = {
            book:     create_or_update_orderbook(Bot::Orderbook::Orderbook.new(market_id), content),
            sequence: content["sequence"],
          }
        when /([^.]+)\.ob-inc/
          market_id = Regexp.last_match(1)
          if @books[market_id].nil?
            return logger.error { "Received a book increment before snapshot on market #{market_id}" }
          end

          if content["sequence"] != @books[market_id][:sequence] + 1
            logger.error { "Sequence out of order (previous: #{@books[market_id][:sequence]} current:#{content['sequence']}, reconnecting websocket..." }
            return @ws.close
          end
          bids = content["bids"] || []
          bids = [bids] if bids.first.is_a?(String) || bids.first.is_a?(Numeric)

          asks = content["asks"] || []
          asks = [asks] if asks.first.is_a?(String) || asks.first.is_a?(Numeric)

          create_or_update_orderbook(@books[market_id][:book], {"bids" => bids}) unless bids.empty?
          create_or_update_orderbook(@books[market_id][:book], {"asks" => asks}) unless asks.empty?

          @books[market_id][:sequence] = content["sequence"]
        end
      end
    end

    def ws_read_private_message(msg)
      if msg["trade"]
        trd = msg["trade"]
        logger.debug { "ACCOUNT:#{id} trade received: #{trd}" }

        if trd["order_id"] # Nusabot >= 2.3
          amount = trd["amount"].to_f
          side = trd["side"].to_sym
          notify_private_trade(Bot::Trade.new(trd["id"], trd["market"].upcase, side, amount, trd["price"].to_f, trd["total"], trd["order_id"]), true)
        else # Nusabot < 2.3
          amount = trd["volume"].to_f
          notify_private_trade(Bot::Trade.new(trd["id"], trd["market"].upcase, :buy, amount, trd["price"].to_f, trd["total"], trd["bid_id"]), false)
          notify_private_trade(Bot::Trade.new(trd["id"], trd["market"].upcase, :sell, amount, trd["price"].to_f, trd["total"], trd["ask_id"]), false)
        end
        return
      end

      if msg["order"]
        ord = msg["order"]
        side = side_from_kind(ord["kind"])
        order = Bot::Order.new(ord["market"].upcase, ord["price"].to_f, ord["remaining_volume"].to_f, side)
        order.id = ord["id"]
        case ord["state"]
        when "wait"
          notify_created_order(order)
        when "cancel", "done"
          notify_deleted_order(order)
        end
        return
      end

      if msg["balances"]
        update_balances(msg["balances"].map {|currency, (free, locked)|
          free = free.to_d
          locked = locked.to_d
          {
            "currency" => currency,
            "free"     => free,
            "locked"   => locked,
            "total"    => free + locked,
          }
        })
        return
      end

      ws_read_public_message(msg)
    end
  end
end
