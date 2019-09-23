use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :stripcross, StripcrossWeb.Endpoint,
  http: [port: 4002],
  server: true

# Print only warnings and errors during test
config :logger, level: :warn

config :stripcross, base_host: "/"

config :stripcross,
  puzzle_selector: "#Puzzle",
  puzzle_class_mappings:
    "something:transformed-something something-else:transformed-something-else",
  clues_selector: "#Clues",
  passthrough_selectors: "#Passthrough #OtherPassthrough #FakePassthrough",
  remove_selectors: ".letter",
  path_template: "FORMATTED_DATE.html",
  date_format: "%Y-%m-%d"
