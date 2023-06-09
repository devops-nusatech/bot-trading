# frozen_string_literal: true

describe Bot::Strategy::SimpleCopy do
  let(:reactor) { double(:reactor) }
  let(:executor) { double(:executor) }
  let(:strategy) { Bot::Strategy::SimpleCopy.new([source], target, config, reactor) }
  let(:account) { Bot::Exchange.create(account_config) }
  let(:target_mode) { Bot::Helpers::Flags::DEFAULT_TARGET_FLAGS }
  let(:source_mode) { Bot::Helpers::Flags::DEFAULT_SOURCE_FLAGS }
  let(:source) { Bot::Market.new(config["sources"].first["market_id"], account, Bot::Helpers::Flags::DEFAULT_SOURCE_FLAGS) }
  let(:target) { Bot::Market.new(config["target"]["market_id"], account, target_mode) }
  let(:spread_asks) { 0.005 }
  let(:spread_bids) { 0.006 }
  let(:levels_size) { 5.0 }
  let(:levels_count) { 10 }

  let(:account_config) do
    {
      "id" => 1,
      "driver" => "bitfaker",
      "params" => {
        "balances" => [
          {
            "currency" => "btc",
            "total" => 3,
            "free" => 3,
            "locked" => 0
          },
          {
            "currency" => "usd",
            "total" => 10_000,
            "free" => 10_000,
            "locked" => 0
          }
        ]
      }
    }
  end
  let(:config) do
    {
      "type" => "simple_copy",
      "params" => {
        "spread_bids" => spread_bids,
        "spread_asks" => spread_asks,
        "levels_size" => levels_size,
        "levels_count" => levels_count,
      },
      "target" => {
        "driver" => "bitfaker",
        "market_id" => "BTCUSD",
      },
      "sources" => [
        "account_id" => 1,
        "market_id" => "BTCUSD",
      ],
    }
  end
  before(:each) do
    source.update_orderbook
    target.account.fetch_balances
    target.account.executor = executor
  end

  context "mid_price" do
    it "calculates mid_price from the source orderbook" do
      expect(strategy.sources.first.mid_price).to eq(138.82)
    end
  end

  context "set_liquidity_limits" do
    it do
      strategy.set_liquidity_limits
      expect(strategy.limit_asks_base).to eq("2.4".to_d)
      expect(strategy.limit_bids_quote).to eq(8_000)
    end
  end

  context "fx" do
    let!(:config) do
      {
        "type" => "simple_copy",
        "params" => {
          "spread_bids" => spread_bids,
          "spread_asks" => spread_asks,
          "levels_size" => levels_size,
          "levels_count" => levels_count,
        },
        "fx" => {
          "type" => "finex",
          "pair" => "btcusd"
        },
        "target" => {
          "driver" => "bitfaker",
          "market_id" => "BTCUSD",
        },
        "sources" => [
          "account_id" => 1,
          "market_id" => "BTCUSD",
        ],
      }
    end

    let(:finex_service) do
      Bot::Fx::Service::Finex.instance
    end

    before(:each) do
      if config["fx"]
        type = config["fx"]["type"]
        fx_klass = Bot::Fx.const_get(type.capitalize)
        strategy.fx = fx_klass.new(config["fx"])
      end
    end

    it "get price from finex" do
      finex_service.send(:ws_read_message, [3, "forex", ["btcusd", "54321", 1_614_137_576_241, 1_614_137_576_241]])
      strategy.call
      expect(54_321.to_d).to eq(finex_service.rate("btcusd"))
      expect(strategy.fx.rate).to eq(finex_service.rate("btcusd"))
    end
  end
end
