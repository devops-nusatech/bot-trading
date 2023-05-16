module Bot
  Kline = Struct.new(:market, :period, :open, :high, :low, :close, :volume, :created_at)
end
