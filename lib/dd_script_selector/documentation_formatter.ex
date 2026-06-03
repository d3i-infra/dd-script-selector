defmodule DdScriptSelector.DocumentationFormatter do
  @moduledoc """
  Formats data-donation task documentation as a markdown string,
  scoped to only the selected tables and selected variables.
  """

  @doc """
  Builds a markdown documentation string from the enabled tables and platform info.
  Only selected (enabled) tables and their selected variables are included.
  """
  def format(tables, platform_info) do
    platform_name = platform_info["platform_name"] || platform_info["name"] || "Unknown"

    enabled_tables = Enum.filter(tables, & &1.enabled)

    table_sections =
      Enum.map_join(enabled_tables, "\n\n", &format_table/1)

    """
    # #{platform_name}

    This document describes the data tables and variables included in the data donation flow for #{platform_name}.

    #{table_sections}
    """
    |> String.trim()
  end

  defp format_table(table) do
    title = get_locale(table.title, "en")
    description = get_locale(table.description, "en")

    columns = selected_columns(table)

    column_section =
      if map_size(columns) == 0 do
        ""
      else
        "\n\n" <> format_columns(columns, table.enabled_headers)
      end

    """
    ## #{title}

    #{description}#{column_section}
    """
    |> String.trim()
  end

  defp selected_columns(table) do
    case table.documentation do
      %{"columns" => cols} ->
        Map.filter(cols, fn {key, _} -> key in table.enabled_headers end)

      _ ->
        %{}
    end
  end

  defp format_columns(columns, enabled_headers) do
    rows =
      enabled_headers
      |> Enum.filter(&Map.has_key?(columns, &1))
      |> Enum.map_join("\n", fn key ->
        desc = column_description(columns[key])
        "| `#{key}` | #{desc} |"
      end)

    """
    | Variable | Description |
    | -------- | ----------- |
    #{rows}
    """
    |> String.trim()
  end

  defp column_description(value) when is_binary(value), do: value
  defp column_description(%{"description" => desc}) when is_binary(desc), do: desc
  defp column_description(_), do: ""

  defp get_locale(map, locale) when is_map(map) do
    map[locale] || map["en"] || Map.values(map) |> List.first() || ""
  end

  defp get_locale(_, _), do: ""
end
