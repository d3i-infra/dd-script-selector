defmodule DdScriptSelector.PlatformsTest do
  use ExUnit.Case, async: true

  alias DdScriptSelector.Platforms

  @task_dir Application.compile_env!(:dd_script_selector, :task_dir)

  describe "list/1" do
    test "returns [] for a nonexistent task dir" do
      assert Platforms.list("/nonexistent/path/that/does/not/exist") == []
    end

    test "returns platforms sorted alphabetically" do
      platforms = Platforms.list(@task_dir)
      names = Enum.map(platforms, & &1.name)
      assert names == Enum.sort(names)
    end

    test "each platform has the expected keys" do
      [platform | _] = Platforms.list(@task_dir)
      assert Map.has_key?(platform, :name)
      assert Map.has_key?(platform, :platform_info)
      assert Map.has_key?(platform, :tables)
      assert Map.has_key?(platform, :available_languages)
    end

    test "each table has the expected keys and defaults" do
      platforms = Platforms.list(@task_dir)
      table = platforms |> Enum.flat_map(& &1.tables) |> hd()

      assert Map.has_key?(table, :id)
      assert Map.has_key?(table, :extractor)
      assert Map.has_key?(table, :title)
      assert Map.has_key?(table, :description)
      assert Map.has_key?(table, :documentation)
      assert Map.has_key?(table, :headers)
      assert table.enabled == true
      assert is_list(table.enabled_headers)
    end

    test "available_languages always includes en first" do
      for platform <- Platforms.list(@task_dir), platform.available_languages != [] do
        assert hd(platform.available_languages) == "en"
      end
    end
  end

  describe "list/0" do
    test "returns a non-empty list using configured task_dir" do
      result = Platforms.list()
      assert is_list(result)
      assert length(result) > 0
    end
  end
end
