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
                <table id=Puzzle>
                  <tr><td>this is preserved</td></tr>
                  <tr>
                    <td class=letter>this is removed</td>
                    <td class="something"></td>
                    <td class="something-else"></td>
                  </tr>
                </table>
                <div id=Clues>
                  <div>1</div>
                  <div>A clue : <a>AN ANSWER</a></div>
                </div>
              </body>
            </html>
            """
          }
        end,
        start: fn -> [] end do
        navigate_to(@page_url)

        assert page_title() == "Hello"

        assert Hound.Matchers.element?(:css, "#Puzzle")

        assert String.contains?(
                 Hound.Helpers.Element.visible_text({:css, "#Puzzle"}),
                 "this is preserved"
               )

        refute Hound.Matchers.element?(:css, "#Puzzle .something")
        assert Hound.Matchers.element?(:css, "#Puzzle .transformed-something")

        refute Hound.Matchers.element?(:css, "#Puzzle .something-else")
        assert Hound.Matchers.element?(:css, "#Puzzle .transformed-something-else")

        assert Hound.Matchers.element?(:css, "#Clues")

        assert Hound.Helpers.Element.visible_text({:css, "#Clues div:first-child"}) ==
                 "1"

        assert Hound.Helpers.Element.visible_text({:css, "#Clues div:last-child"}) ==
                 "A clue :"

        refute Hound.Matchers.element?(:css, "#Clues a")

        refute Hound.Matchers.element?(:css, "#ignored")
        refute Hound.Matchers.element?(:css, ".letter")
      end
    end

    test "warns of unknown puzzle classes", _meta do
      with_mock HTTPoison,
        get!: fn _url ->
          %{
            body: """
            <html>
              <head>
                <title>Hello</title>
              </head>
              <body>
                <table id=Puzzle>
                  <tr>
                    <td class="something"></td>
                    <td class="unknown"></td>
                    <td class="unknown"></td>
                  </tr>
                </table>
                <div id=Clues>
                </div>
              </body>
            </html>
            """
          }
        end,
        start: fn -> [] end do
        navigate_to(@page_url)

        assert Hound.Helpers.Element.visible_text({:css, ".warning"}) ==
                 "Puzzle contains unknown class(es): unknown"
      end
    end

    test "navigates to today’s puzzle by default, or by date directly", _meta do
      with_mock HTTPoison,
        get!: fn url ->
          today_string = Timex.format!(Timex.now(), "%Y-%m-%d", :strftime)
          today_string_url = "/#{today_string}.html"

          title =
            case url do
              ^today_string_url -> "Today"
              _ -> url
            end

          %{
            body: """
            <html>
              <head>
                <title>#{title}</title>
              </head>
              <body>
                <table id=Puzzle>
                  <tr>
                    <td class="something"></td>
                    <td class="unknown"></td>
                    <td class="unknown"></td>
                  </tr>
                </table>
                <div id=Clues>
                </div>
              </body>
            </html>
            """
          }
        end,
        start: fn -> [] end do
        navigate_to(@page_url)

        assert page_title() == "Today"

        navigate_to(page_url(StripcrossWeb.Endpoint, :index, "2019-01-01"))

        assert page_title() == "/2019-01-01.html"
      end
    end
  end
end
