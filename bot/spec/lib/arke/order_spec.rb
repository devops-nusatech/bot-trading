# frozen_string_literal: true

describe Bot::Order do
  let(:order1) { Bot::Order.new("ethusd", 1, 1, :buy) }
  let(:order2) { Bot::Order.new("ethusd", 1, 1, :buy) }
  let(:order3) { Bot::Order.new("btcusd", 1, 1, :buy) }
  let(:order4) { Bot::Order.new("ethusd", 2, 1, :buy) }
  let(:order5) { Bot::Order.new("ethusd", 1, 2, :buy) }
  let(:order6) { Bot::Order.new("ethusd", 1, 1, :sell) }
  let(:order7) { Bot::Order.new("ethusd", 1, 1, :buy, "market") }

  it "supports comparison" do
    expect(order1).to eq(order2)
    expect(order1).to_not eq(order3)
    expect(order1).to_not eq(order4)
    expect(order1).to_not eq(order5)
    expect(order1).to_not eq(order6)
    expect(order1).to_not eq(order7)
  end

  context "apply_precision" do
    let(:target_config) do
      {
        "id"     => 1,
        "driver" => "bitfaker",
      }
    end
    let(:target_account) { Bot::Exchange.create(target_config) }

    it "applies target market precision for price and amount" do
      order = Bot::Order.new("BTCUSD", 1.123456789, 2.456789123, :buy)
      order.apply_requirements(target_account)
      expect(order.price).to eq(1.123456)
      expect(order.amount).to eq(2.456789)

      order = Bot::Order.new("BTCUSD", 2.456789123, 1.123456789, :buy)
      order.apply_requirements(target_account)
      expect(order.price).to eq(2.456789)
      expect(order.amount).to eq(1.123456)
    end

    it "applies target market minimum order specification" do
      order = Bot::Order.new("BTCUSD", 1.123456789, 0.045678912, :buy)
      order.apply_requirements(target_account)
      expect(order.price).to eq(1.123456)
      expect(order.amount).to eq(0.1)
      expect(order.price_s).to eq("1.123456")
      expect(order.amount_s).to eq("0.100000")
    end

    it "doesn't change price and amount if the precision is correct" do
      order = Bot::Order.new("BTCUSD", 1.123456, 2.456789, :buy)
      order.apply_requirements(target_account)
      expect(order.price).to eq(1.123456)
      expect(order.amount).to eq(2.456789)
      expect(order.price_s).to eq("1.123456")
      expect(order.amount_s).to eq("2.456789")

      order = Bot::Order.new("BTCUSD", 2.45, 1.12, :buy)
      order.apply_requirements(target_account)
      expect(order.price).to eq(2.45)
      expect(order.amount).to eq(1.12)
      expect(order.price_s).to eq("2.450000")
      expect(order.amount_s).to eq("1.120000")
    end

    it "applies min_order_size according to precision" do
      expect(target_account).to receive(:market_config).and_return(
        {
          "id"               => "htusdt",
          "base_unit"        => "ht",
          "quote_unit"       => "usdt",
          "min_price"        => nil,
          "max_price"        => nil,
          "min_amount"       => 0.1,
          "amount_precision" => 2,
          "price_precision"  => 4,
          "min_order_size"   => 5,
        }
      )
      order = Bot::Order.new("htusdt", "14.56".to_d, "0.1".to_d, :buy)
      order.apply_requirements(target_account)
      expect(order.price).to eq("14.56".to_d)
      expect(order.amount).to eq("0.35".to_d)
      expect(order.price_s).to eq("14.5600")
      expect(order.amount_s).to eq("0.35")
    end
  end
end
