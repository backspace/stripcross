defmodule StripcrossWeb.PageController do
  use StripcrossWeb, :controller

  def index(conn, _params) do
    HTTPoison.start()

    url = Application.get_env(:stripcross, :base_host)
    response = HTTPoison.get!(url)

    conn
    |> html(response.body)
  end
end
