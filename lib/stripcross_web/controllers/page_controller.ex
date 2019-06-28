defmodule StripcrossWeb.PageController do
  use StripcrossWeb, :controller

  def index(conn, _params) do
    HTTPoison.start()

    url = Application.get_env(:stripcross, :base_host)
    body = HTTPoison.get!(url).body

    title = ModestEx.find(body, "title")
    puzzle_table = ModestEx.find(body, Application.get_env(:stripcross, :puzzle_selector))

    clues_selector = Application.get_env(:stripcross, :clues_selector)
    clues = ModestEx.find(body, clues_selector)

    transformed =
      ModestEx.append("<html><head>#{title}</head><body></body></html>", "body", puzzle_table)
      |> ModestEx.remove(".letter")
      |> ModestEx.append("body", clues)
      |> ModestEx.remove("#{clues_selector} a")

    conn
    |> html(transformed)
  end
end
