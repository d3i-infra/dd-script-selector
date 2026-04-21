defmodule DdScriptSelector.Platforms do
  @moduledoc """
  Lists available platform scripts from the cloned data-donation-task repository.
  """

  alias DdScriptSelector.PyDocExtractor

  @doc """
  Lists platforms from the configured platforms directory.

  Returns a list of platform maps sorted alphabetically by filename.
  Each map has keys: `:name`, `:platform_info`, `:tables`, `:available_languages`.
  """
  def list do
    dir = Application.fetch_env!(:dd_script_selector, :platforms_dir)
    list(dir) 
  end

  @doc """
  Lists platforms from the given directory path. Returns `[]` if the
  directory does not exist or cannot be read.
  """
  def list(dir) do
    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".py"))
        |> Enum.sort()
        |> Enum.map(fn filename ->
          path = Path.join(dir, filename)
          name = filename |> Path.rootname() |> String.capitalize()
          extracted = PyDocExtractor.extract(path)
          platform_info = extract_platform_info(extracted)
          {tables, available_languages} = extract_table_config(extracted)
          %{name: name, platform_info: platform_info, tables: tables, available_languages: available_languages}
        end)

      {:error, _} ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp extract_platform_info({:error, _}), do: nil
  defp extract_platform_info(%{platform_info_json: nil}), do: nil

  defp extract_platform_info(%{platform_info_json: json}) do
    case Jason.decode(json) do
      {:ok, info} -> info
      _ -> nil
    end
  end

  defp extract_table_config({:error, _}), do: {[], []}
  defp extract_table_config(%{table_config_json: nil}), do: {[], []}

  defp extract_table_config(%{table_config_json: json, functions: functions}) do
    case Jason.decode(json) do
      {:ok, %{"tables" => raw_tables}} ->
        func_docs = Map.new(functions, fn %{name: name, doc: doc} -> {name, doc} end)
        tables = Enum.map(raw_tables, &normalize_table(&1, func_docs))
        {tables, derive_languages(tables)}

      _ ->
        {[], []}
    end
  end

  defp normalize_table(raw, func_docs) do
    headers = raw["headers"] || %{}
    extractor = raw["extractor"]
    documentation = func_docs |> Map.get(extractor) |> extract_table_documentation()

    %{
      id: raw["id"],
      extractor: extractor,
      title: raw["title"] || %{},
      description: raw["description"] || %{},
      documentation: documentation,
      headers: headers,
      extractor_kwargs: raw["extractor_kwargs"] || %{},
      visualizations: raw["visualizations"] || [],
      variables: raw["variables"],
      enabled: true,
      enabled_headers: headers |> Map.keys() |> Enum.sort()
    }
  end

  defp extract_table_documentation(nil), do: nil

  defp extract_table_documentation(doc) do
    case Regex.run(~r/Table documentation::\n([\s\S]*)/s, doc) do
      [_, block] ->
        case YamlElixir.read_from_string(block) do
          {:ok, map} when is_map(map) -> map
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp derive_languages([]), do: []

  defp derive_languages([first | _]) do
    keys = Map.keys(first.title)
    (["en"] ++ Enum.sort(keys -- ["en"])) |> Enum.uniq()
  end
end
