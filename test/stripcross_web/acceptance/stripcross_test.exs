defmodule HoundTest do
  use ExUnit.Case
  use Hound.Helpers
  import StripcrossWeb.Router.Helpers
  import Mock

  @page_url page_url(StripcrossWeb.Endpoint, :index)
  @path_date_format "%Y-%m-%d"

  setup do
    Hound.start_session(user_agent: "Agent")
    :ok
  end

  describe "homepage" do
    test "homepage loads stripped source page with user agent passthrough", _meta do
      with_mock HTTPoison,
        get!: fn _url, [{"User-Agent", [user_agent]}] ->
          assert user_agent == "Agent"

          %{
            body: """
            <html>
              <head>
                <title>Hello</title>
              </head>
              <body>
                <div id=ignored>this is ignored</div>
                <h1 id=Title></h1>
                <h2 id=Subtitle></h2>
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
                <div>
                  <h1 id=IgnoredTitle></h1>
                  <h2 id=IgnoredSubtitle></h2>
                </div>
              </body>
            </html>
            """
          }
        end,
        start: fn -> [] end do
        navigate_to(@page_url)

        assert page_title() == "Hello"

        assert Hound.Matchers.element?(:css, "#Title")
        assert Hound.Matchers.element?(:css, "#Subtitle")

        refute Hound.Matchers.element?(:css, "#IgnoredTitle")
        refute Hound.Matchers.element?(:css, "#IgnoredSubtitle")

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
                 "A clue"

        refute Hound.Matchers.element?(:css, "#Clues a")

        refute Hound.Matchers.element?(:css, "#ignored")
        refute Hound.Matchers.element?(:css, ".letter")

        assert Hound.Matchers.element?(:css, ".container #Puzzle")
        assert Hound.Matchers.element?(:css, ".container #Clues")
      end
    end

    test "warns of unknown puzzle classes and ignores non-following h2s", _meta do
      with_mock HTTPoison,
        get!: fn _url, _headers ->
          %{
            body: """
            <html>
              <head>
                <title>Hello</title>
              </head>
              <body>
                <h1 id=Title></h1>
                <table id=Puzzle>
                  <tr>
                    <td class="something"></td>
                    <td class="unknown"></td>
                    <td class="unknown"></td>
                  </tr>
                </table>
                <h2 id=NonSubtitle></h2>
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

        assert Hound.Matchers.element?(:css, "#Title")
        refute Hound.Matchers.element?(:css, "#NonSubtitle")
      end
    end

    test "navigates to today’s puzzle by default, or by date directly, with prev/next day links",
         _meta do
      with_mock HTTPoison,
        get!: fn url, _headers ->
          today_string = Timex.format!(Timex.local(), @path_date_format, :strftime)
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

        assert Hound.Matchers.element?(:css, "a.previous")

        yesterday_string =
          Timex.local()
          |> Timex.subtract(Timex.Duration.from_days(1))
          |> Timex.format!(@path_date_format, :strftime)

        assert String.ends_with?(
                 Hound.Helpers.Element.attribute_value({:css, "a.previous"}, "href"),
                 yesterday_string
               )

        refute Hound.Matchers.element?(:css, "a.next")

        navigate_to(glob_router_url(StripcrossWeb.Endpoint, [], ["2019-01-01"]))

        past_date = Timex.parse!("2019-01-01", @path_date_format, :strftime)

        assert page_title() == "/2019-01-01.html"

        yesterday_string =
          past_date
          |> Timex.subtract(Timex.Duration.from_days(1))
          |> Timex.format!(@path_date_format, :strftime)

        assert String.ends_with?(
                 Hound.Helpers.Element.attribute_value({:css, "a.previous"}, "href"),
                 yesterday_string
               )

        tomorrow_string =
          past_date
          |> Timex.add(Timex.Duration.from_days(1))
          |> Timex.format!(@path_date_format, :strftime)

        assert String.ends_with?(
                 Hound.Helpers.Element.attribute_value({:css, "a.next"}, "href"),
                 tomorrow_string
               )
      end
    end
  end
end
