defmodule DdScriptSelector.Platforms do
  @moduledoc """
  Lists available platform scripts from the cloned data-donation-task repository.
  """

  alias DdScriptSelector.PyDocExtractor

  @doc """
  Lists platforms from the configured platforms directory.

  Returns a list of platform maps sorted alphabetically by filename.
  Each map has keys: `:name`, `:doc`, `:tables`, `:available_languages`.
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
          doc = extract_doc(extracted)
          {tables, available_languages} = extract_config(extracted)
          %{name: name, doc: doc, tables: tables, available_languages: available_languages}
        end)

      {:error, _} ->
        []
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp extract_doc({:error, _}), do: nil
  defp extract_doc(%{module_doc: doc}), do: doc

  defp extract_config({:error, _}), do: {[], []}
  defp extract_config(%{config_json: nil}), do: {[], []}

  defp extract_config(%{config_json: json}) do
    case Jason.decode(json) do
      {:ok, %{"tables" => raw_tables}} ->
        tables = Enum.map(raw_tables, &normalize_table/1)
        {tables, derive_languages(tables)}

      _ ->
        {[], []}
    end
  end

  defp normalize_table(raw) do
    headers = raw["headers"] || %{}

    %{
      id: raw["id"],
      extractor: raw["extractor"],
      title: raw["title"] || %{},
      description: raw["description"] || %{},
      headers: headers,
      extractor_kwargs: raw["extractor_kwargs"] || %{},
      visualizations: raw["visualizations"] || [],
      variables: raw["variables"],
      enabled: true,
      enabled_headers: headers |> Map.keys() |> Enum.sort()
    }
  end

  defp derive_languages([]), do: []

  defp derive_languages([first | _]) do
    keys = Map.keys(first.title)
    (["en"] ++ Enum.sort(keys -- ["en"])) |> Enum.uniq()
  end
end
