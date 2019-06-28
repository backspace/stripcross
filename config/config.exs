# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

# Configures the endpoint
config :stripcross, StripcrossWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "mrXbcLGLphocTi0X2mvaMhCRf8oSqxkQHUUBEHwT1/QOzVezHJnpZVlvRlTX4ahV",
  render_errors: [view: StripcrossWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Stripcross.PubSub, adapter: Phoenix.PubSub.PG2]

config :stripcross, base_host: System.get_env("BASE_HOST")

config :stripcross,
  puzzle_selector: System.get_env("PUZZLE_SELECTOR"),
  clues_selector: System.get_env("CLUES_SELECTOR")

config :hound, driver: "chrome_driver", browser: "chrome_headless"
config :modest_ex, scope: :html

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
