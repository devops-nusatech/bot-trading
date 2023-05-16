# frozen_string_literal: true

module Bot::Command
  class Start < ::Clamp::Command
    include Bot::Helpers::Commands
    option "--dry", :flag, "dry run on the target"
    option "--config", "FILE_PATH", "Strategies configuration file, -- for stdin", default: "config/strategies.yml"

    def execute
      Bot::Log.level = Logger::Severity.const_get(conf["log_level"].upcase || "INFO")
      Bot::Reactor.new(strategies_configs, accounts_configs, dry?).run
    end
  end
end
