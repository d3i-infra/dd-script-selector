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
  end

  describe "list/0" do
    test "returns a list (smoke test against the default dir)" do
      result = Platforms.list()
      assert is_list(result)
    end
  end
end
