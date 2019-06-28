defmodule StripcrossWeb.PageControllerTest do
  use StripcrossWeb.ConnCase

  import Mock

  test "GET /", %{conn: conn} do
    with_mock HTTPoison,
      get!: fn _url -> %{body: "<html>hey</html>"} end,
      start: fn -> [] end do
      conn = get(conn, "/")
      assert html_response(conn, 200) =~ "hey"
    end
  end
end
