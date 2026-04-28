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
    task_dir = Application.fetch_env!(:dd_script_selector, :task_dir)
    list(task_dir)
  end

  @doc """
  Lists platforms from `task_dir`, the root of the data-donation-task repository.
  Returns `[]` if the platforms directory does not exist or cannot be read.
  """
  def list(task_dir) do
    dir = Path.join(task_dir, "packages/python/port/platforms")

    case File.ls(dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.ends_with?(&1, ".py"))
        |> Enum.sort()
        |> Enum.flat_map(fn filename ->
          name = Path.rootname(filename)

          case PyDocExtractor.extract(name, task_dir) do
            {:ok, config} -> [build_platform(name, config)]
            _ -> []
          end
        end)

      {:error, _} ->
        []
    end
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
