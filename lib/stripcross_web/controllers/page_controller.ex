defmodule StripcrossWeb.PageController do
  use StripcrossWeb, :controller

  def index(conn, _params) do
    HTTPoison.start()

    url = Application.get_env(:stripcross, :base_host)
    body = HTTPoison.get!(url).body

    title = ModestEx.find(body, "title")
    puzzle_table = ModestEx.find(body, Application.get_env(:stripcross, :puzzle_selector))

    transformed =
      ModestEx.append("<html><head>#{title}</head><body></body></html>", "body", puzzle_table)

    conn
    |> html(transformed)
  end
end
