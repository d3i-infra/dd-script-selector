defmodule DdScriptSelector.PyDocExtractorTest do
  use ExUnit.Case, async: true

  alias DdScriptSelector.PyDocExtractor

  # ---------------------------------------------------------------------------
  # functions
  # ---------------------------------------------------------------------------

  describe "parse/1 - functions" do
    test "extracts a function with a docstring" do
      python = """
      def greet(name):
          \"\"\"Return a greeting.\"\"\"
          return f"Hello, {name}"
      """

      [func] = PyDocExtractor.parse(python).functions
      assert func.name == "greet"
      assert func.doc == "Return a greeting."
    end

    test "extracts a function without a docstring" do
      python = """
      def add(a, b):
          return a + b
      """

      [func] = PyDocExtractor.parse(python).functions
      assert func.name == "add"
      assert func.doc == nil
    end

    test "extracts multiple functions in order" do
      python = """
      def alpha():
          \"\"\"First.\"\"\"
          pass

      def beta():
          \"\"\"Second.\"\"\"
          pass
      """

      functions = PyDocExtractor.parse(python).functions
      assert length(functions) == 2
      assert Enum.at(functions, 0).name == "alpha"
      assert Enum.at(functions, 0).doc == "First."
      assert Enum.at(functions, 1).name == "beta"
      assert Enum.at(functions, 1).doc == "Second."
    end

    test "extracts a multi-line function docstring" do
      python = """
      def process(data):
          \"\"\"
          Processes data.
          Returns a result.
          \"\"\"
          pass
      """

      [func] = PyDocExtractor.parse(python).functions
      assert func.doc =~ "Processes data."
      assert func.doc =~ "Returns a result."
    end

    test "does not capture nested (non-top-level) function definitions" do
      python = """
      def outer():
          \"\"\"Outer doc.\"\"\"
          def inner():
              \"\"\"Inner doc.\"\"\"
              pass
          return inner
      """

      functions = PyDocExtractor.parse(python).functions
      assert length(functions) == 1
      assert hd(functions).name == "outer"
    end

    test "handles a file with no functions" do
      python = "x = 1\ny = 2\n"
      assert PyDocExtractor.parse(python).functions == []
    end

    test "handles a function with no arguments" do
      python = """
      def noop():
          pass
      """

      [func] = PyDocExtractor.parse(python).functions
      assert func.name == "noop"
    end

    test "handles a function with a type-annotated return" do
      python = """
      def count() -> int:
          \"\"\"Returns count.\"\"\"
          return 0
      """

      [func] = PyDocExtractor.parse(python).functions
      assert func.name == "count"
      assert func.doc == "Returns count."
    end

    test "extracts a function with a multiline signature" do
      python = """
      def followers_to_df(
          reader: ZipArchiveReader,
          errors: Counter,
          *,
          filename: str = "followers_1.json",
      ) -> pd.DataFrame:
          \"\"\"Extract the list of followers into a DataFrame.

          Parameters
          ----------
          reader:
              Archive reader used to load JSON files from the DDP zip.
          errors:
              Mutable counter that accumulates error type counts.
          filename:
              Path inside the zip archive to read.

          Returns
          -------
          pd.DataFrame
              Columns: ``Account``, ``URL``, ``Date``.
          \"\"\"
          pass
      """

      [func] = PyDocExtractor.parse(python).functions
      assert func.name == "followers_to_df"
      assert func.doc =~ "Extract the list of followers into a DataFrame."
      assert func.doc =~ "Parameters"
      assert func.doc =~ "Returns"
      assert func.doc =~ "pd.DataFrame"
    end

    test "extracts multiple functions where some have multiline signatures" do
      python = """
      def simple(x):
          \"\"\"Simple doc.\"\"\"
          return x

      def complex_fn(
          a: int,
          b: str = "default",
      ) -> bool:
          \"\"\"Complex doc.\"\"\"
          return True
      """

      functions = PyDocExtractor.parse(python).functions
      assert length(functions) == 2
      assert Enum.at(functions, 0).name == "simple"
      assert Enum.at(functions, 0).doc == "Simple doc."
      assert Enum.at(functions, 1).name == "complex_fn"
      assert Enum.at(functions, 1).doc == "Complex doc."
    end
  end

  # ---------------------------------------------------------------------------
  # table_config_json
  # ---------------------------------------------------------------------------

  describe "parse/1 - table_config_json" do
    test "extracts the triple-quoted DEFAULT_TABLE_CONFIG_JSON string" do
      python = """
      \"\"\"Module doc.\"\"\"

      DEFAULT_TABLE_CONFIG_JSON: str = \"\"\"
      {\"tables\": [{\"id\": \"t1\"}]}
      \"\"\"
      """

      assert PyDocExtractor.parse(python).table_config_json == "{\"tables\": [{\"id\": \"t1\"}]}"
    end

    test "returns nil when DEFAULT_TABLE_CONFIG_JSON is absent" do
      assert PyDocExtractor.parse("x = 1\n").table_config_json == nil
    end

    test "trims surrounding whitespace from the extracted JSON string" do
      python = """
      DEFAULT_TABLE_CONFIG_JSON: str = \"\"\"
        {\"tables\": []}
      \"\"\"
      """

      assert PyDocExtractor.parse(python).table_config_json == "{\"tables\": []}"
    end
  end

  # ---------------------------------------------------------------------------
  # extract/1
  # ---------------------------------------------------------------------------

  describe "extract/1" do
    test "reads and parses a real file" do
      path = Path.join(System.tmp_dir!(), "test_py_doc_#{System.unique_integer([:positive])}.py")

      File.write!(path, """
      \"\"\"A temp module.\"\"\"

      def hello():
          \"\"\"Says hello.\"\"\"
          pass
      """)

      on_exit(fn -> File.rm(path) end)

      result = PyDocExtractor.extract(path)
      assert length(result.functions) == 1
      assert hd(result.functions).name == "hello"
    end

    test "returns an error tuple for a missing file" do
      assert {:error, :enoent} = PyDocExtractor.extract("/nonexistent/path/file.py")
    end
  end
end
