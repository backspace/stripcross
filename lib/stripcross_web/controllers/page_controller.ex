defmodule StripcrossWeb.PageController do
  use StripcrossWeb, :controller
  require Logger

  @path_date_format "%Y-%m-%d"
  @readable_date_format "%A %B %-d"

  def index(conn, _params) do
    HTTPoison.start()

    base_url = Application.get_env(:stripcross, :base_host)

    source_date_format = Application.get_env(:stripcross, :source_date_format)

    {path_date, request_date, is_today} =
      case conn.path_info do
        [] ->
          date = Timex.local()
          {Timex.format!(date, source_date_format, :strftime), date, true}

        [path_date] ->
          parsed_date = Timex.parse!(path_date, @path_date_format, :strftime)
          source_formatted_date_string = Timex.format!(parsed_date, source_date_format, :strftime)
          {source_formatted_date_string, parsed_date, Timex.equal?(Timex.now(), parsed_date, :day)}
      end

    path_template = Application.get_env(:stripcross, :path_template)
    path = String.replace(path_template, "FORMATTED_DATE", path_date)

    url = "#{base_url}#{path}"

    case Stripcross.Cache.has_key?(url) do
      true ->
        cached_with_links = Stripcross.Cache.get(url)
        |> add_navigation_links(request_date, is_today)

        conn
        |> html(cached_with_links)
      false ->
        user_agent = get_req_header(conn, "user-agent")

        case HTTPoison.get(url, [{"User-Agent", user_agent}]) do
          {:ok, %{body: body, status_code: 200}} ->
            title = ModestEx.find(body, "title")

            puzzle_selector = Application.get_env(:stripcross, :puzzle_selector)
            puzzle_table = ModestEx.find(body, puzzle_selector)

            case puzzle_table do
              {:error, _} ->
                conn
                |> html("<p>The source page didn’t contain a puzzle! Is the date correct?</p>")
              _ ->
                clues_selector = Application.get_env(:stripcross, :clues_selector)
                clues = ModestEx.find(body, clues_selector)
            
                document = """
                <html>
                  <head>
                    <style>
                      html {
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                      }
            
                      h1 {
                        display: inline-block;
                        font-size: 1.5em;
                        margin: 0;
                      }
            
                      h2 {
                        display: inline-block;
                        font-size: 1em;
                        margin: 0 0 0 1rem;
                      }
            
                      @media print {
                        a.previous, a.next {
                          display: none;
                        }
                      }
            
                      a.previous + a.next {
                        margin-left: 1rem;
                      }
            
                      .warning {
                        background: pink;
                        padding: 1em;
                      }
            
                      table {
                        border-collapse: collapse;
                        float: right;
                      }
            
                      td {
                        position: relative;
                        width: 22px;
                        height: 22px;
            
                        padding: 0;
            
                        border: 1px solid black;
                        vertical-align: top;
            
                        font-size: 8px;
                      }
            
                      td.filled {
                        background: repeating-linear-gradient(
                          45deg,
                          white,
                          #888 2px,
                          white 2px,
                          #888 2px
                        );
                      }

                      td.shaded {
                        background: #d3d3d3;
                      }
            
                      td.circled *:first-child::after {
                        content: '';
                        position: absolute;
                        border-radius: 22px;
                        border: 1px solid black;
                        width: 17px;
                        height: 17px;
                        top: 2px;
                        left: 3px;
                      }
            
                      #{clues_selector} {
                        column-count: 3;
                      }
            
                      #{clues_selector} div div:nth-child(2) {
                        max-width: 15em;
                      }
            
                      #{clues_selector} div div div {
                        display: inline;
                      }
            
                      #{clues_selector} div div div:nth-child(odd) {
                        font-size: 9px;
                        font-weight: bold;
                        padding-right: 3px;
                      }
            
                      #{clues_selector} div div div:nth-child(even) {
                        font-size: 10px;
                      }
            
                      #{clues_selector} div div div:nth-child(even)::after {
                        content: '';
                        display: block;
                      }
                    </style>
                    #{title}
                  </head>
                  <body>
                  </body>
                </html>
                """
            
                transformed =
                  ModestEx.append(document, "body", "<div class='container'></div>")
                  |> ModestEx.append(".container", puzzle_table)
                  |> ModestEx.append(".container", clues)
                  |> ModestEx.remove("#{clues_selector} a")
                  |> String.replace(" : <", "<")
                
                remove_selectors_string = Application.get_env(:stripcross, :remove_selectors)
            
                remove_selectors =
                  String.split(remove_selectors_string, " ")
                
                transformed =
                  Enum.reduce(remove_selectors, transformed, fn selector, transformed ->
                    ModestEx.remove(transformed, selector)
                  end)
            
                puzzle_class_mappings_string = Application.get_env(:stripcross, :puzzle_class_mappings)
            
                puzzle_class_mappings =
                  String.split(puzzle_class_mappings_string, " ")
                  |> Enum.map(&String.split(&1, ":"))
                  |> Map.new(&List.to_tuple/1)
            
                transformed =
                  Enum.reduce(puzzle_class_mappings, transformed, fn {original_class, transformed_class},
                                                                    transformed ->
                    ModestEx.set_attribute(
                      transformed,
                      "#{puzzle_selector} .#{original_class}",
                      "class",
                      transformed_class
                    )
                  end)
            
                puzzle_classes =
                  ModestEx.get_attribute(transformed, "#{puzzle_selector} td", "class")
                  |> Enum.uniq()
            
                unknown_puzzle_classes = puzzle_classes -- Map.values(puzzle_class_mappings)
            
                transformed =
                  case unknown_puzzle_classes do
                    [] ->
                      transformed
            
                    _ ->
                      ModestEx.prepend(
                        transformed,
                        "body",
                        "<p class='warning'>Puzzle contains unknown class(es): #{
                          Enum.join(unknown_puzzle_classes, ", ")
                        }</p>"
                      )
                  end
            
                passthrough_element_selectors =
                  Application.get_env(:stripcross, :passthrough_selectors)
                  |> String.split(" ")
            
                transformed =
                  Enum.reduce(passthrough_element_selectors, transformed, fn selector, transformed ->
                    element_find = ModestEx.find(body, selector)
            
                    case element_find do
                      {:error, _} -> transformed
                      _ -> ModestEx.prepend(transformed, "body", element_find)
                    end
                  end)
            
                h1_find = ModestEx.find(body, "h1:first-of-type")
            
                transformed =
                  case h1_find do
                    {:error, _} ->
                      transformed
            
                    _ ->
                      with_h1 = ModestEx.prepend(transformed, "body", self_or_first(h1_find))
            
                      h2_find = ModestEx.find(body, "h1 + h2:first-of-type")
            
                      case h2_find do
                        {:error, _} -> with_h1
                        _ -> ModestEx.insert_after(with_h1, "h1", self_or_first(h2_find))
                      end
                  end
            
                Stripcross.Cache.set(url, transformed)

                transformed = add_navigation_links(transformed, request_date, is_today)

                conn
                |> html(transformed)
                end

          {:ok, %{status_code: code}} ->
            conn
            |> html("<p>The source site returned an unexpected #{code} code.</p>")
          {:error, %{reason: reason}} ->
            conn
            |> html("<p>The source site returned an error: #{reason}</p>")
          end
    end
  end

  defp self_or_first(array) when is_list(array), do: hd(array)
  defp self_or_first(self), do: self

  defp add_navigation_links(transformed, request_date, is_today) do
    yesterday =
      request_date
      |> Timex.subtract(Timex.Duration.from_days(1))

    yesterday_path =
      yesterday
      |> Timex.format!(@path_date_format, :strftime)

    yesterday_string =
      yesterday
      |> Timex.format!(@readable_date_format, :strftime)

    transformed =
      ModestEx.insert_before(
        transformed,
        ".container",
        "<a href='#{yesterday_path}' class='previous'>« #{yesterday_string}</a>"
      )

    case is_today do
      true ->
        transformed

      false ->
        tomorrow =
          request_date
          |> Timex.add(Timex.Duration.from_days(1))

        tomorrow_path =
          tomorrow
          |> Timex.format!(@path_date_format, :strftime)

        tomorrow_string =
          tomorrow
          |> Timex.format!(@readable_date_format, :strftime)

        ModestEx.insert_after(
          transformed,
          "a.previous",
          "<a href='#{tomorrow_path}' class='next'>#{tomorrow_string} »</a>"
        )
    end
  end
end
