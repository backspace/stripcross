defmodule HoundTest do
  use ExUnit.Case
  use Hound.Helpers
  import StripcrossWeb.Router.Helpers
  import Mock

  @page_url page_url(StripcrossWeb.Endpoint, :index)

  setup do
    Hound.start_session()
    :ok
  end

  describe "homepage" do
    test "homepage loads successfully", _meta do
      with_mock HTTPoison,
        get!: fn _url -> %{body: "<html><head><title>Hello</title></head></html>"} end,
        start: fn -> [] end do
        navigate_to(@page_url)
        assert page_title() == "Hello"
      end
    end
  end
end
