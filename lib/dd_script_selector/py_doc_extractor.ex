defmodule DdScriptSelector.PyDocExtractor do
  @moduledoc """
  Generates platform configuration by running the generate-config command.
  """

  @doc """
  Runs `pnpm run generate-config <platform_name> --stdout` in `task_dir` and
  returns `{:ok, config_map}` or `{:error, reason}`.
  """
  def extract(platform_name, task_dir) do
    case System.cmd("pnpm", ["--silent", "generate-config", platform_name, "--stdout"],
           cd: task_dir,
           stderr_to_stdout: false
         ) do
      {json, 0} -> Jason.decode(json)
      {_output, _code} -> {:error, :command_failed}
    end
  end
end
