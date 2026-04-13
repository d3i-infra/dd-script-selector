defmodule DdScriptSelector.PyDocExtractor do
  @moduledoc """
  Extracts module and function docstrings from a Python (.py) file.
  """

  @doc """
  Reads a Python file and returns a map with:
  - `:module_doc` - the module-level docstring, or nil
  - `:functions`  - list of `%{name: string, doc: string | nil}`
  """
  def extract(file_path) do
    with {:ok, content} <- File.read(file_path) do
      parse(content)
    end
  end

  @doc """
  Parses Python source code from a string. Same return shape as `extract/1`.
  """
  def parse(content) do
    %{
      module_doc: extract_module_doc(content),
      functions: extract_functions(content),
      config_json: extract_config_json(content)
    }
  end

  # --- Module docstring ---

  defp extract_module_doc(content) do
    case Regex.run(~r/\A\s*(\"\"\"|''')([\s\S]*?)\1/s, content) do
      [_, _, doc] -> String.trim(doc)
      _ -> nil
    end
  end

  # --- Function extraction ---
  #
  # Matches only top-level `def` lines (anchored to start of line via `m` flag).
  # Captures the indented body that follows.

  defp extract_functions(content) do
    Regex.scan(
      ~r/^def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([^)]*\)[^:\n]*:\n((?:[ \t]+[^\n]*\n?)*)/m,
      content
    )
    |> Enum.map(fn [_, name, body] ->
      %{name: name, doc: extract_function_doc(body)}
    end)
  end

  defp extract_function_doc(body) do
    case Regex.run(~r/\A\s*(\"\"\"|''')([\s\S]*?)\1/s, body) do
      [_, _, doc] -> String.trim(doc)
      _ -> nil
    end
  end

  # --- Config JSON extraction ---

  defp extract_config_json(content) do
    case Regex.run(~r/DEFAULT_CONFIG_JSON[^=\n]*=\s*"""([\s\S]*?)"""/s, content) do
      [_, json] -> String.trim(json)
      _ -> nil
    end
  end
end
