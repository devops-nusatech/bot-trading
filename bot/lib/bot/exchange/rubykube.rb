# frozen_string_literal: true

module Bot::Exchange
  class Rubykube < Nusabot

    def initialize(config)
      super
      logger.warn "rubykube driver is deprecated, use Nusabot or finex instead"
    end
  end
end