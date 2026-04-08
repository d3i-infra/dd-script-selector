defmodule DdScriptSelector.Platforms do
  @moduledoc """
  Lists available platform scripts from the cloned data-donation-task repository.
  """

  alias DdScriptSelector.PyDocExtractor
  alias DdScriptSelector.RepoSyncer

  @doc """
  Lists platforms from the default platforms directory in the cloned repo.

  Returns a list of `%{name: String.t(), doc: String.t() | nil}` maps,
  sorted alphabetically by filename.
  """
  def list do
    default_dir = RepoSyncer.platforms_dir()
    dir = Application.get_env(:dd_script_selector, :platforms_dir, default_dir)
    list(dir)
  end

  @doc """
  Lists platforms from the given directory path.

  Returns a list of `%{name: String.t(), doc: String.t() | nil}` maps,
  sorted alphabetically by filename. Returns `[]` if the directory does not
  exist or cannot be read.
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
          doc = extract_doc(path)
          %{name: name, doc: doc}
        end)

      {:error, _} ->
        []
    end
  end

  defp extract_doc(path) do
    case PyDocExtractor.extract(path) do
      {:error, _} -> nil
      %{module_doc: doc} -> doc
    end
  end
end
