defmodule DdScriptSelector.PyDocExtractorTest do
  use ExUnit.Case, async: true

  alias DdScriptSelector.PyDocExtractor

  @task_dir Application.compile_env!(:dd_script_selector, :task_dir)

  describe "extract/2" do
    test "returns a map with platform_info and tables for a known platform" do
      assert {:ok, config} = PyDocExtractor.extract("instagram", @task_dir)
      assert is_map(config["platform_info"])
      assert is_list(config["tables"])
    end

    test "returns an error for an unknown platform" do
      assert {:error, _} = PyDocExtractor.extract("nonexistent_platform_xyz", @task_dir)
    end
  end
end
