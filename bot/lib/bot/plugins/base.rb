# frozen_string_literal: true

module Bot::Plugin
  # Base class for all plugins
  class Base
    attr_reader :logger, :name

    def initialize(id, params)
      @logger = Bot::Log
      @id = id
      check_config(params)
      @logger.info { "PLUGIN:#{@id} is activated" }
    end

    def check_config(params)
      raise "check_config is not implemented"
    end
  end
end
