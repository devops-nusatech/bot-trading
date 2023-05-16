# frozen_string_literal: true

require "clamp"
require "rbtree"
require "json"
require "openssl"
require "ostruct"
require "yaml"
require "colorize"
require "em-synchrony"
require "em-synchrony/em-http"
require "faraday"
require "faraday_middleware"
require "better-faraday"
require "faye/websocket"
require "bigdecimal"
require "bigdecimal/util"
require 'singleton'

require "bitx"
require "rack"

module Bot; end

require "bot/helpers/precision"
require "bot/helpers/commands"
require "bot/helpers/price_points"
require "bot/helpers/spread"
require "bot/helpers/flags"
require "bot/helpers/orderbook"
require "bot/helpers/array"
require "bot/helpers/flat_params_encoder"

require "bot/configuration"
require "bot/log"
require "bot/reactor"
require "bot/exchange"
require "bot/strategy"
require "bot/models/market"
require "bot/models/action"
require "bot/models/order"
require "bot/models/trade"
require "bot/models/kline"
require "bot/models/ticker"
require "bot/models/price_point"
require "bot/fx/static"
require "bot/fx/fixer"
require "bot/fx/finex"
require "bot/fx/service/finex"
require "bot/action_executor"
require "bot/scheduler/simple"
require "bot/scheduler/smart"

require "bot/plugins/base"
require "bot/plugins/limit_balance"

require "bot/orderbook/base"
require "bot/orderbook/orderbook"
require "bot/orderbook/aggregated"
require "bot/orderbook/open_orders"
require "bot/orderbook/generator"

require "bot/strategy/base"
require "bot/strategy/copy"
require "bot/strategy/fixedprice"
require "bot/strategy/microtrades_copy"
require "bot/strategy/microtrades_market"
require "bot/strategy/microtrades"
require "bot/strategy/orderback"
require "bot/strategy/circuitbraker"
require "bot/strategy/candle_sampling"
require "bot/strategy/simple_copy"

require "bot/exchange/base"
require "bot/exchange/binance"
require "bot/exchange/bitfaker"
require "bot/exchange/bitfinex"
require "bot/exchange/hitbtc"
require "bot/exchange/huobi"
require "bot/exchange/kraken"
require "bot/exchange/luno"
require "bot/exchange/okex"
require "bot/exchange/nusabot"
require "bot/exchange/finex"
require "bot/exchange/rubykube"
require "bot/exchange/valr"

require "bot/command"
require "bot/command/order"
require "bot/command/show"
require "bot/command/start"
require "bot/command/version"
require "bot/command/root"
