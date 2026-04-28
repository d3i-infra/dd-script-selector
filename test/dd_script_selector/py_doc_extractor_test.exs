defmodule DdScriptSelector.PyDocExtractorTest do
  use ExUnit.Case, async: true

  alias DdScriptSelector.PyDocExtractor

  describe "extract/1" do
    test "returns a map with platform_info and tables for a known platform" do
      assert {:ok, config} = PyDocExtractor.extract("instagram")
      assert is_map(config["platform_info"])
      assert is_list(config["tables"])
    end

    test "returns an error for an unknown platform" do
      assert {:error, _} = PyDocExtractor.extract("nonexistent_platform_xyz")
    end
  end
end
