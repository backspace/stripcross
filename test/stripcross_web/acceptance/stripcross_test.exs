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
    test "homepage loads stripped source page", _meta do
      puzzle_selector = Application.get_env(:stripcross, :puzzle_selector)
      puzzle_id = String.slice(puzzle_selector, 1..-1)

      with_mock HTTPoison,
        get!: fn _url ->
          %{
            body:
              "<html><head><title>Hello</title></head><body><div id=ignored>this is ignored</div><div id=#{
                puzzle_id
              }>this is preserved</div></body></html>"
          }
        end,
        start: fn -> [] end do
        navigate_to(@page_url)

        assert page_title() == "Hello"

        assert Hound.Matchers.element?(:css, puzzle_selector)
        refute Hound.Matchers.element?(:css, "#ignored")
      end
    end
  end
end
