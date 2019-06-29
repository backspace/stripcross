defmodule StripcrossWeb.PageController do
  use StripcrossWeb, :controller

  def index(conn, _params) do
    HTTPoison.start()

    url = Application.get_env(:stripcross, :base_host)
    body = HTTPoison.get!(url).body

    title = ModestEx.find(body, "title")

    puzzle_selector = Application.get_env(:stripcross, :puzzle_selector)
    puzzle_table = ModestEx.find(body, puzzle_selector)

    clues_selector = Application.get_env(:stripcross, :clues_selector)
    clues = ModestEx.find(body, clues_selector)

    document = """
    <html>
      <head>
        <style>
          table {
            border-collapse: collapse;
          }

          td {
            width: 2rem;
            height: 2rem;

            border: 1px solid black;
            vertical-align: top;

            font-family: sans-serif;
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
        </style>
        #{title}
      </head>
      <body>
      </body>
    </html>
    """

    transformed =
      ModestEx.append(document, "body", puzzle_table)
      |> ModestEx.remove(".letter")
      |> ModestEx.append("body", clues)
      |> ModestEx.remove("#{clues_selector} a")

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

    conn
    |> html(transformed)
  end
end
