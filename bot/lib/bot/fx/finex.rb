# frozen_string_literal: true

module Bot::Fx
  class Finex < Static
    attr_reader :logger, :provider, :pair

    def initialize(config)
      @logger = Bot::Log
      @pair = config["pair"]&.downcase
      check_config

      @svc = Bot::Fx::Service::Finex.instance
      @svc.register(@pair)
      @svc.host = config["host"] if config["host"]
    end

    def check_config
      raise "pair is missing" if @pair.to_s.empty?
    end

    def start
      @svc.start
    end

    def rate
      @svc.rate(pair)
    end
  end
end
