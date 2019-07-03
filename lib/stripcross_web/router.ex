defmodule StripcrossWeb.Router do
  use StripcrossWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", StripcrossWeb do
    pipe_through :browser

    get "/", PageController, :index
    get "/*path", GlobRouter, []
  end

  # Other scopes may use custom stacks.
  # scope "/api", StripcrossWeb do
  #   pipe_through :api
  # end
end

defmodule StripcrossWeb.GlobRouter do
  def init(opts), do: opts

  def call(%Plug.Conn{request_path: path} = conn, _opts) do
    cond do
      Regex.match?(~r/^\/\d{4}-\d{2}-\d{2}$/, path) ->
        to(conn, StripcrossWeb.PageController, :index)

      true ->
        raise Phoenix.Router.NoRouteError, conn: conn, router: StripcrossWeb.Router
    end
  end

  defp to(conn, controller, action) do
    controller.call(conn, controller.init(action))
  end
end
