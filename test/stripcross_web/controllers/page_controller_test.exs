defmodule StripcrossWeb.PageControllerTest do
  use StripcrossWeb.ConnCase

  test "GET /something-else", %{conn: conn} do
    assert_error_sent :not_found, fn ->
      get(conn, "/something-else")
    end
  end
end
