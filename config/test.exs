use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :stripcross, StripcrossWeb.Endpoint,
  http: [port: 4002],
  server: true

# Print only warnings and errors during test
config :logger, level: :warn

config :stripcross,
  puzzle_selector: "#Puzzle",
  clues_selector: "#Clues"
