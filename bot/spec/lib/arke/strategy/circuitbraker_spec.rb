# frozen_string_literal: true


describe Bot::Strategy::Circuitbraker do
  let(:reactor) { double(:reactor) }
  let(:strategy) { Bot::Strategy::Circuitbraker.new([source], target, config, reactor) }
  let(:account) { Bot::Exchange.create(account_config) }
  let(:target_mode) { Bot::Helpers::Flags::DEFAULT_TARGET_FLAGS }
  let(:source_mode) { Bot::Helpers::Flags::DEFAULT_SOURCE_FLAGS }
  let(:source) { Bot::Market.new(config["sources"].first["market_id"], account, Bot::Helpers::Flags::DEFAULT_SOURCE_FLAGS) }
  let(:target) { Bot::Market.new(config["target"]["market_id"], account, target_mode) }
  let(:spread_asks) { 0.005 }
  let(:spread_bids) { 0.006 }
  let(:executor) { double(:executor) }

  let(:account_config) do
    {
      "id"     => 1,
      "driver" => "bitfaker",
    }
  end
  let(:config) do
    {
      "id"      => "circuitbraker-test",
      "type"    => "circuitbraker",
      "params"  => {
        "spread_bids" => spread_bids,
        "spread_asks" => spread_asks,
      },
      "target"  => {
        "driver"    => "bitfaker",
        "market_id" => "BTCUSD",
      },
      "sources" => [
        "account_id" => 1,
        "market_id"  => "BTCUSD",
      ],
    }
  end
  before(:each) do
    source.update_orderbook
    target.account.fetch_balances
    target.account.executor = executor
  end

  context "orders are out of bounds" do
    it "cancels them" do
      order14 = Bot::Order.new("BTCUSD", 139.45, 1, :sell, "limit", 14)
      order15 = Bot::Order.new("BTCUSD", 135, 1, :sell, "limit", 15)
      order16 = Bot::Order.new("BTCUSD", 137.95, 1, :buy, "limit", 16)
      order17 = Bot::Order.new("BTCUSD", 140.95, 1, :buy, "limit", 17)

      target.add_order(order14)
      target.add_order(order15)
      target.add_order(order16)
      target.add_order(order17)

      expect(executor).to receive(:push).with(
        "circuitbraker-test",
        [
          Bot::Action.new(:order_stop, target, order: order15, priority: 1_000_000_004.5543),
          Bot::Action.new(:order_stop, target, order: order17, priority: 1_000_000_003.00268),
          Bot::Action.new(:order_stop, target, order: order14, priority: 1_000_000_000.1043),
          Bot::Action.new(:order_stop, target, order: order16, priority: 1_000_000_000.00268),
        ]
      )
      strategy.call
    end
  end

  context "no orders are out of bounds" do
    it "does nothing" do
      order14 = Bot::Order.new("BTCUSD", 139.56, 1, :sell, "limit", 14)
      order15 = Bot::Order.new("BTCUSD", 140, 1, :sell, "limit", 15)
      order16 = Bot::Order.new("BTCUSD", 137.93, 1, :buy, "limit", 16)
      order17 = Bot::Order.new("BTCUSD", 135.95, 1, :buy, "limit", 17)

      target.add_order(order14)
      target.add_order(order15)
      target.add_order(order16)
      target.add_order(order17)

      expect(executor).to_not receive(:push)
      strategy.call
    end
  end

  context "with fx" do
    let(:fx) { ::Bot::Fx::Static.new(fx_config) }

    let(:fx_config) do
      {
        "type" => "static",
        "rate" => rate,
      }
    end

    let(:rate) { 10.0 }

    before(:each) do
      strategy.fx = fx
    end

    context "orders are out of bounds" do
      it "cancels them" do
        order14 = Bot::Order.new("BTCUSD", 1394.5, 1, :sell, "limit", 14)
        order15 = Bot::Order.new("BTCUSD", 1350, 1, :sell, "limit", 15)
        order16 = Bot::Order.new("BTCUSD", 1379.5, 1, :buy, "limit", 16)
        order17 = Bot::Order.new("BTCUSD", 1409.5, 1, :buy, "limit", 17)

        target.add_order(order14)
        target.add_order(order15)
        target.add_order(order16)
        target.add_order(order17)

        expect(executor).to receive(:push).with(
          "circuitbraker-test",
          [
            Bot::Action.new(:order_stop, target, order: order15, priority: "1_000_000_045.543".to_d),
            Bot::Action.new(:order_stop, target, order: order17, priority: "1_000_000_030.0268".to_d),
            Bot::Action.new(:order_stop, target, order: order14, priority: "1_000_000_001.043".to_d),
            Bot::Action.new(:order_stop, target, order: order16, priority: "1_000_000_000.0268".to_d),
          ]
        )
        strategy.call
      end
    end

    context "no orders are out of bounds" do
      it "does nothing" do
        order14 = Bot::Order.new("BTCUSD", 1395.6, 1, :sell, "limit", 14)
        order15 = Bot::Order.new("BTCUSD", 1400, 1, :sell, "limit", 15)
        order16 = Bot::Order.new("BTCUSD", 1379.3, 1, :buy, "limit", 16)
        order17 = Bot::Order.new("BTCUSD", 1359.5, 1, :buy, "limit", 17)

        target.add_order(order14)
        target.add_order(order15)
        target.add_order(order16)
        target.add_order(order17)

        expect(executor).to_not receive(:push)
        strategy.call
      end
    end
  end

  context "no open orders" do
    it "does nothing" do
      expect(executor).to_not receive(:push)
      strategy.call
    end
  end
end
