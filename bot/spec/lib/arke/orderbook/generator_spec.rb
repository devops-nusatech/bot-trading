# frozen_string_literal: true

describe Bot::Orderbook::Generator do
  let(:gen) { Bot::Orderbook::Generator.new }
  let(:shape) { "V" }
  let(:levels) { nil }
  let(:params) do
    {
      levels_count:      5,
      levels_price_step: 1,
      random:            0,
      market:            "abcusd",
      best_ask_price:    100,
      best_bid_price:    99,
      shape:             shape,
      levels:            levels
    }
  end

  context "V shape" do
    let(:shape) { "V" }

    it do
      ob, pps = gen.generate(params)
      expect(ob.book[:sell].to_hash).to eq(
        100.to_d => 1,
        101.to_d => 2,
        102.to_d => 3,
        103.to_d => 4,
        104.to_d => 5
      )
      expect(pps[:asks]).to eq(
        [
          ::Bot::PricePoint.new(101),
          ::Bot::PricePoint.new(102),
          ::Bot::PricePoint.new(103),
          ::Bot::PricePoint.new(104),
          ::Bot::PricePoint.new(105)
        ]
      )
      expect(ob.book[:buy].to_hash).to eq(
        99.to_d => 1,
        98.to_d => 2,
        97.to_d => 3,
        96.to_d => 4,
        95.to_d => 5
      )
      expect(pps[:bids]).to eq(
        [
          ::Bot::PricePoint.new(98),
          ::Bot::PricePoint.new(97),
          ::Bot::PricePoint.new(96),
          ::Bot::PricePoint.new(95),
          ::Bot::PricePoint.new(94)
        ]
      )
    end
  end

  context "W shape" do
    let(:shape) { "W" }

    it do
      ob, pps = gen.generate(params)
      expect(ob.book[:sell].to_hash).to eq(
        100.to_d => 1,
        101.to_d => 2,
        102.to_d => 1,
        103.to_d => 2,
        104.to_d => 3
      )
      expect(pps[:asks]).to eq(
        [
          ::Bot::PricePoint.new(101),
          ::Bot::PricePoint.new(102),
          ::Bot::PricePoint.new(103),
          ::Bot::PricePoint.new(104),
          ::Bot::PricePoint.new(105)
        ]
      )
      expect(ob.book[:buy].to_hash).to eq(
        99.to_d => 1,
        98.to_d => 2,
        97.to_d => 1,
        96.to_d => 2,
        95.to_d => 3
      )
      expect(pps[:bids]).to eq(
        [
          ::Bot::PricePoint.new(98),
          ::Bot::PricePoint.new(97),
          ::Bot::PricePoint.new(96),
          ::Bot::PricePoint.new(95),
          ::Bot::PricePoint.new(94)
        ]
      )
    end
  end

  context "custom shape" do
    let(:shape) { "custom" }
    let(:levels) do
      [0.1, 1, 2, 0.1]
    end
    it do
      ob, pps = gen.generate(params)
      expect(ob.book[:sell].to_hash).to eq(
        100.to_d => 0.1,
        101.to_d => 1,
        102.to_d => 2,
        103.to_d => 0.1,
        104.to_d => 0.1
      )
      expect(pps[:asks]).to eq(
        [
          ::Bot::PricePoint.new(101),
          ::Bot::PricePoint.new(102),
          ::Bot::PricePoint.new(103),
          ::Bot::PricePoint.new(104),
          ::Bot::PricePoint.new(105)
        ]
      )
      expect(ob.book[:buy].to_hash).to eq(
        99.to_d => 0.1,
        98.to_d => 1,
        97.to_d => 2,
        96.to_d => 0.1,
        95.to_d => 0.1
      )
      expect(pps[:bids]).to eq(
        [
          ::Bot::PricePoint.new(98),
          ::Bot::PricePoint.new(97),
          ::Bot::PricePoint.new(96),
          ::Bot::PricePoint.new(95),
          ::Bot::PricePoint.new(94)
        ]
      )
    end
  end
end
