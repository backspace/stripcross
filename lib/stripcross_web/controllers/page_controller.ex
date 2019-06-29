defmodule StripcrossWeb.PageController do
  use StripcrossWeb, :controller
  require Logger

  def index(conn, _params) do
    HTTPoison.start()

    base_url = Application.get_env(:stripcross, :base_host)

    date_format = Application.get_env(:stripcross, :date_format)

    path_date =
      case conn.path_info do
        [] -> Timex.format!(Timex.now(), date_format, :strftime)
        [date] -> date
      end

    path_template = Application.get_env(:stripcross, :path_template)
    path = String.replace(path_template, "FORMATTED_DATE", path_date)

    url = "#{base_url}#{path}"

    user_agent = get_req_header(conn, "user-agent")

    body = HTTPoison.get!(url, [{"User-Agent", user_agent}]).body

    title = ModestEx.find(body, "title")

    puzzle_selector = Application.get_env(:stripcross, :puzzle_selector)
    puzzle_table = ModestEx.find(body, puzzle_selector)

    clues_selector = Application.get_env(:stripcross, :clues_selector)
    clues = ModestEx.find(body, clues_selector)

    document = """
    <html>
      <head>
        <style>
          html {
            font-family: sans-serif;
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
            width: 25px;
            height: 25px;

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

          td.circled *:first-child::after {
            content: '';
            position: absolute;
            border-radius: 25px;
            border: 1px solid black;
            width: 20px;
            height: 20px;
            top: 2px;
            left: 3px;
          }

          #{clues_selector} {
            display: flex;
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
      |> ModestEx.remove(".letter")
      |> ModestEx.append(".container", clues)
      |> ModestEx.remove("#{clues_selector} a")
      |> String.replace(" : <", "<")

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

    conn
    |> html(transformed)
  end

  defp self_or_first(array) when is_list(array), do: hd(array)
  defp self_or_first(self), do: self
end
