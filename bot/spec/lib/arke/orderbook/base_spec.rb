# frozen_string_literal: true

describe Bot::Orderbook::Base do
  let(:market)     { "ethusd" }
  let(:orderbook)  { Bot::Orderbook::Base.new(market) }
  let(:order_sell_0)     { Bot::Order.new(market, 5, 1, :sell) }
  let(:order_sell_1)     { Bot::Order.new(market, 8, 1, :sell) }
  let(:order_sell_cheap) { Bot::Order.new(market, 2, 1, :sell) }
  let(:order_buy_0)         { Bot::Order.new(market, 5, 1, :buy) }
  let(:order_buy_1)         { Bot::Order.new(market, 8, 1, :buy) }
  let(:order_buy_expensive) { Bot::Order.new(market, 9, 1, :buy) }

  it "creates orderbook" do
    orderbook = Bot::Orderbook::Base.new(market)

    expect(orderbook.book).to include(sell: ::RBTree.new)
  end

  context "orderbook#contains?" do
    let(:order0) { Bot::Order.new(market, 5, 1, :buy) }
    let(:order1) { Bot::Order.new(market, 8, 1, :buy) }

    it "returns true if order is in orderbook" do
      orderbook.update(order0)
      orderbook.update(order1)

      expect(orderbook.contains?(order0)).to equal(true)
      expect(orderbook.contains?(order1)).to equal(true)
    end

    it "returns false if order is not in orderbook" do
      expect(orderbook.contains?(order0)).to equal(false)
    end
  end

  context "orderbook#get" do
    it "gets order with the lowest price for sell side" do
      orderbook.update(order_sell_0)
      orderbook.update(order_sell_1)
      orderbook.update(order_sell_cheap)

      expect(orderbook.get(:sell)[0]).to equal(order_sell_cheap.price)
    end

    it "gets order with the highest price for buy side" do
      orderbook.update(order_buy_0)
      orderbook.update(order_buy_1)
      orderbook.update(order_buy_expensive)

      expect(orderbook.get(:buy)[0]).to equal(order_buy_expensive.price)
    end
  end

  context "orderbook#last" do
    it "gets order with the highest price for sell side" do
      orderbook.update(order_sell_0)
      orderbook.update(order_sell_1)
      orderbook.update(order_sell_cheap)

      expect(orderbook.last(:sell)[0]).to equal(order_sell_1.price)
    end

    it "gets order with the lowest price for buy side" do
      orderbook.update(order_buy_0)
      orderbook.update(order_buy_1)
      orderbook.update(order_buy_expensive)
      expect(orderbook.last(:buy)[0]).to equal(order_buy_0.price)
    end
  end

  context "orderbook#spead" do
    it "duplicate the orderbook introducing a spread" do
      orderbook.update(order_sell_0)
      orderbook.update(order_sell_1)
      orderbook.update(order_sell_cheap)
      orderbook.update(order_buy_0)
      orderbook.update(order_buy_1)
      orderbook.update(order_buy_expensive)
      ob_spread = orderbook.spread(0.01, 0.02)
      expect(ob_spread[:buy].to_hash).to eq(
        8.91.to_d => 1.to_d,
        7.92.to_d => 1.to_d,
        4.95.to_d => 1.to_d
      )
      expect(ob_spread[:sell].to_hash).to eq(
        2.04.to_d => 1.to_d,
        5.10.to_d => 1.to_d,
        8.16.to_d => 1.to_d,
      )
    end
  end

  context "group_by_level" do
    let(:price_points_sell) { [::Bot::PricePoint.new(6), ::Bot::PricePoint.new(8)] }
    let(:order_sell_0)     { ::Bot::Order.new("ethusd", 5, 1, :sell) }
    let(:order_sell_1)     { ::Bot::Order.new("ethusd", 8, 2, :sell) }
    let(:order_sell_2)     { ::Bot::Order.new("ethusd", 2, 3, :sell) }

    before(:each) do
      orderbook.update(order_sell_0)
      orderbook.update(order_sell_1)
      orderbook.update(order_sell_2)
    end

    it "returns list of orders amount for every level" do
      expect(orderbook.group_by_level(:sell, price_points_sell)).to eq(
        [
          {price: 6, orders: [3, 1]},
          {price: 8, orders: [2]},
        ]
      )
    end
  end
end
