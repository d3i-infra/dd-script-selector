defmodule DdScriptSelector.Platforms do
  @moduledoc """
  Lists available platform scripts from the configured platforms list.
  """

  alias DdScriptSelector.PyDocExtractor

  @doc """
  Lists platforms from the configured `:platforms` list.

  Returns a list of platform maps sorted alphabetically by name.
  Each map has keys: `:name`, `:platform_info`, `:tables`, `:available_languages`.
  """
  def list do
    platforms = Application.fetch_env!(:dd_script_selector, :platforms)

    platforms
    |> Enum.sort()
    |> Enum.flat_map(fn name ->
      case PyDocExtractor.extract(name) do
        {:ok, config} -> [build_platform(name, config)]
        _ -> []
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp build_platform(name, %{"platform_info" => info, "tables" => raw_tables}) do
    tables = Enum.map(raw_tables, &normalize_table/1)
    languages = info["languages"] || []
    available_languages = (["en"] ++ Enum.sort(languages -- ["en"])) |> Enum.uniq()

    %{
      name: String.capitalize(name),
      platform_info: info,
      tables: tables,
      available_languages: available_languages
    }
  end

  defp normalize_table(raw) do
    headers = raw["headers"] || %{}

    %{
      id: raw["id"],
      extractor: raw["extractor"],
      title: raw["title"] || %{},
      description: raw["description"] || %{},
      documentation: raw["documentation"],
      headers: headers,
      extractor_kwargs: raw["extractor_kwargs"] || %{},
      visualizations: raw["visualizations"] || [],
      variables: raw["variables"],
      enabled: true,
      enabled_headers: headers |> Map.keys() |> Enum.sort()
    }
  end
end
