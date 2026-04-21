defmodule DdScriptSelector.PyDocExtractor do
  @moduledoc """
  Extracts module and function docstrings from a Python (.py) file.
  """

  @doc """
  Reads a Python file and returns a map with:
  - `:platform_info_json` - the raw JSON string from `PLATFORM_INFO_JSON`, or nil
  - `:functions`  - list of `%{name: string, doc: string | nil}`
  - `:table_config_json` - the raw JSON string from `DEFAULT_TABLE_CONFIG_JSON`, or nil
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
      platform_info_json: extract_platform_info_json(content),
      functions: extract_functions(content),
      table_config_json: extract_table_config_json(content)
    }
  end

  # --- Platform info JSON extraction ---

  defp extract_platform_info_json(content) do
    case Regex.run(~r/PLATFORM_INFO_JSON[^=\n]*=\s*"""([\s\S]*?)"""/s, content) do
      [_, json] -> String.trim(json)
      _ -> nil
    end
  end

  # --- Function extraction ---
  #
  # Matches only top-level `def` lines (anchored to start of line via `m` flag).
  # Captures the indented body that follows.

  defp extract_functions(content) do
    Regex.scan(
      ~r/^def\s+([a-zA-Z_][a-zA-Z0-9_]*)\s*\([\s\S]*?\)[^:\n]*:\n((?:(?:[ \t]+[^\n]*)?\n)*)/m,
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

  # --- Table config JSON extraction ---

  defp extract_table_config_json(content) do
    case Regex.run(~r/DEFAULT_TABLE_CONFIG_JSON[^=\n]*=\s*"""([\s\S]*?)"""/s, content) do
      [_, json] -> String.trim(json)
      _ -> nil
    end
  end
end
