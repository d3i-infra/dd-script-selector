defmodule DdScriptSelector.PlatformsTest do
  use ExUnit.Case, async: true

  alias DdScriptSelector.Platforms

  describe "list/0" do
    test "returns a non-empty list" do
      result = Platforms.list()
      assert is_list(result)
      assert length(result) > 0
    end

    test "returns platforms sorted alphabetically" do
      names = Platforms.list() |> Enum.map(& &1.name)
      assert names == Enum.sort(names)
    end

    test "each platform has the expected keys" do
      [platform | _] = Platforms.list()
      assert Map.has_key?(platform, :name)
      assert Map.has_key?(platform, :platform_info)
      assert Map.has_key?(platform, :tables)
      assert Map.has_key?(platform, :available_languages)
    end

    test "each table has the expected keys and defaults" do
      table = Platforms.list() |> Enum.flat_map(& &1.tables) |> hd()

      assert Map.has_key?(table, :id)
      assert Map.has_key?(table, :extractor)
      assert Map.has_key?(table, :title)
      assert Map.has_key?(table, :description)
      assert Map.has_key?(table, :documentation)
      assert Map.has_key?(table, :headers)
      assert table.enabled == true
      assert is_list(table.enabled_headers)
      assert Map.has_key?(table, :headers_order)
      assert is_list(table.headers_order)
      assert table.headers_order == (table.headers |> Map.keys() |> Enum.sort())
    end

    test "available_languages always includes en first" do
      for platform <- Platforms.list(), platform.available_languages != [] do
        assert hd(platform.available_languages) == "en"
      end
    end
  end
end
