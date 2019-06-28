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
            body: """
            <html>
              <head>
                <title>Hello</title>
              </head>
              <body>
                <div id=ignored>this is ignored</div>
                <div id=#{puzzle_id}>
                  this is preserved
                  <div class=letter>this is removed</div>
                </div>
              </body>
            </html>
            """
          }
        end,
        start: fn -> [] end do
        navigate_to(@page_url)

        assert page_title() == "Hello"

        assert Hound.Matchers.element?(:css, puzzle_selector)

        assert String.contains?(
                 Hound.Helpers.Element.visible_text({:css, puzzle_selector}),
                 "this is preserved"
               )

        refute Hound.Matchers.element?(:css, "#ignored")
        refute Hound.Matchers.element?(:css, ".letter")
      end
    end
  end
end
