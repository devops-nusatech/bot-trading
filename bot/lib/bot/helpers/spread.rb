# frozen_string_literal: true

module Bot::Helpers
  module Spread
    def apply_spread(side, price, spread)
      mult = 1 + (side == :sell ? spread : -spread)
      price * mult
    end

    def remove_spread(side, price, spread)
      mult = 1 + (side == :sell ? spread : -spread)
      price / mult
    end
  end
end
