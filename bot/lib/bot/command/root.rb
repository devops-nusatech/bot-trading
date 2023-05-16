# frozen_string_literal: true

module Bot::Command
  class Root < ::Clamp::Command
    subcommand "start", "Starting the bot", Start
    subcommand "show", "Show accounts informations", Show
    subcommand "order", "Create an order using an account", Order
    subcommand "version", "Print the Bot version", Version
  end
end
