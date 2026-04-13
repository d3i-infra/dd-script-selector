defmodule DdScriptSelector.PlatformsTest do
  use ExUnit.Case, async: true

  alias DdScriptSelector.Platforms

  defp tmp_dir do
    dir = Path.join(System.tmp_dir!(), "platforms_test_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    dir
  end

  describe "list/1" do
    test "returns platforms from .py files with correct name and doc" do
      dir = tmp_dir()

      File.write!(Path.join(dir, "instagram.py"), """
      \"\"\"Instagram platform module.\"\"\"

      def process():
          pass
      """)

      platforms = Platforms.list(dir)

      assert length(platforms) == 1
      [platform] = platforms
      assert platform.name == "Instagram"
      assert platform.doc == "Instagram platform module."
    end

    test "returns nil doc when .py file has no module docstring" do
      dir = tmp_dir()

      File.write!(Path.join(dir, "twitter.py"), """
      import os

      def process():
          pass
      """)

      [platform] = Platforms.list(dir)
      assert platform.name == "Twitter"
      assert platform.doc == nil
    end

    test "ignores non-.py files" do
      dir = tmp_dir()

      File.write!(Path.join(dir, "readme.txt"), "some text")
      File.write!(Path.join(dir, "data.json"), "{}")
      File.write!(Path.join(dir, "facebook.py"), "\"\"\"Facebook module.\"\"\"\n")

      platforms = Platforms.list(dir)
      assert length(platforms) == 1
      assert hd(platforms).name == "Facebook"
    end

    test "returns [] for a nonexistent dir" do
      assert Platforms.list("/nonexistent/path/that/does/not/exist") == []
    end

    test "returns platforms sorted alphabetically by filename" do
      dir = tmp_dir()

      File.write!(Path.join(dir, "youtube.py"), "\"\"\"YouTube.\"\"\"\n")
      File.write!(Path.join(dir, "amazon.py"), "\"\"\"Amazon.\"\"\"\n")
      File.write!(Path.join(dir, "netflix.py"), "\"\"\"Netflix.\"\"\"\n")

      platforms = Platforms.list(dir)
      names = Enum.map(platforms, & &1.name)
      assert names == ["Amazon", "Netflix", "Youtube"]
    end

    test "returns tables and available_languages from DEFAULT_CONFIG_JSON" do
      dir = tmp_dir()

      File.write!(Path.join(dir, "myplatform.py"), """
      \"\"\"My platform.\"\"\"

      DEFAULT_CONFIG_JSON: str = \"\"\"
      {
        "tables": [
          {
            "id": "t1",
            "extractor": "extract_t1",
            "title": {"en": "Table One", "nl": "Tabel Een"},
            "description": {"en": "Desc.", "nl": "Omschr."},
            "headers": {
              "Name": {"en": "Name", "nl": "Naam"},
              "Date": {"en": "Date", "nl": "Datum"}
            }
          }
        ]
      }
      \"\"\"
      """)

      [platform] = Platforms.list(dir)
      assert length(platform.tables) == 1

      [table] = platform.tables
      assert table.id == "t1"
      assert table.extractor == "extract_t1"
      assert table.title == %{"en" => "Table One", "nl" => "Tabel Een"}
      assert table.enabled == true
      assert Enum.sort(table.enabled_headers) == ["Date", "Name"]

      assert platform.available_languages == ["en", "nl"]
    end

    test "returns empty tables and languages when DEFAULT_CONFIG_JSON is absent" do
      dir = tmp_dir()
      File.write!(Path.join(dir, "simple.py"), "\"\"\"Simple.\"\"\"\n")

      [platform] = Platforms.list(dir)
      assert platform.tables == []
      assert platform.available_languages == []
    end

    test "returns empty tables when config JSON is invalid" do
      dir = tmp_dir()

      File.write!(Path.join(dir, "broken.py"), """
      \"\"\"Broken.\"\"\"

      DEFAULT_CONFIG_JSON: str = \"\"\"
      not valid json
      \"\"\"
      """)

      [platform] = Platforms.list(dir)
      assert platform.tables == []
    end
  end

  describe "list/0" do
    test "returns a list (smoke test against the default dir)" do
      result = Platforms.list()
      assert is_list(result)
    end
  end
end
