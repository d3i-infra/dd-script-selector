defmodule DdScriptSelectorWeb.ScriptSelectorLiveTest do
  # async: false because Application.put_env/3 is global state
  use DdScriptSelectorWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @fixture_alpha """
  \"\"\"
  Alpha platform module docstring.
  \"\"\"

  DEFAULT_CONFIG_JSON: str = \"\"\"
  {
    "tables": [
      {
        "id": "alpha_table_one",
        "extractor": "extract_one",
        "title": {"en": "Table One", "nl": "Tabel Een"},
        "description": {"en": "The first table.", "nl": "De eerste tabel."},
        "headers": {
          "Name": {"en": "Name", "nl": "Naam"},
          "Date": {"en": "Date", "nl": "Datum"}
        }
      },
      {
        "id": "alpha_table_two",
        "extractor": "extract_two",
        "title": {"en": "Table Two", "nl": "Tabel Twee"},
        "description": {"en": "The second table.", "nl": "De tweede tabel."},
        "headers": {
          "Value": {"en": "Value", "nl": "Waarde"}
        }
      }
    ]
  }
  \"\"\"
  """

  @fixture_beta """
  \"\"\"
  Beta platform module docstring.
  \"\"\"
  """

  setup do
    tmp_dir =
      System.tmp_dir!() |> Path.join("script_selector_test_#{System.unique_integer([:positive])}")

    File.mkdir_p!(tmp_dir)
    File.write!(Path.join(tmp_dir, "alpha.py"), @fixture_alpha)
    File.write!(Path.join(tmp_dir, "beta.py"), @fixture_beta)

    Application.put_env(:dd_script_selector, :platforms_dir, tmp_dir)

    on_exit(fn ->
      Application.delete_env(:dd_script_selector, :platforms_dir)
      File.rm_rf!(tmp_dir)
    end)

    :ok
  end

  test "page mounts and shows the platform list sidebar", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")
    assert has_element?(view, "#platform-list")
    assert has_element?(view, "#platform-Alpha")
    assert has_element?(view, "#platform-Beta")
  end

  test "initially shows the prompt in the right panel", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")
    assert has_element?(view, "#detail-prompt", "Select a platform to get started.")
  end

  test "selecting a platform shows the detail panel with name and docstring", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Alpha label input") |> render_click()

    assert has_element?(view, "#detail-panel")
    assert has_element?(view, "#detail-panel h1", "Alpha")
    assert has_element?(view, "#detail-panel", "Alpha platform module docstring.")
    refute has_element?(view, "#detail-prompt")
  end

  test "selecting a platform with config shows table cards", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Alpha label input") |> render_click()

    assert has_element?(view, "#table-alpha_table_one")
    assert has_element?(view, "#table-alpha_table_two")
    assert has_element?(view, "#table-alpha_table_one", "Table One")
  end

  test "selecting a platform with two languages shows the language toggle", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Alpha label input") |> render_click()

    assert has_element?(view, "#language-toggle")
    assert has_element?(view, "#language-toggle button", "en")
    assert has_element?(view, "#language-toggle button", "nl")
  end

  test "selecting a platform without config hides the language toggle", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Beta label input") |> render_click()

    refute has_element?(view, "#language-toggle")
  end

  test "changing language updates table titles", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Alpha label input") |> render_click()
    assert has_element?(view, "#table-alpha_table_one", "Table One")

    view |> element("#language-toggle button", "nl") |> render_click()

    assert has_element?(view, "#table-alpha_table_one", "Tabel Een")
  end

  test "toggle_table disables a table card", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Alpha label input") |> render_click()

    # Variable checkboxes visible for enabled table
    assert has_element?(view, "#variables-alpha_table_one")

    view |> element("#table-alpha_table_one input[phx-click=toggle_table]") |> render_click()

    # Variable checkboxes hidden after disabling table
    refute has_element?(view, "#variables-alpha_table_one")
  end

  test "toggle_variable removes a variable from the table", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Alpha label input") |> render_click()

    assert has_element?(view, "#variables-alpha_table_one input[value=Name]")

    view
    |> element("#variables-alpha_table_one input[value=Name]")
    |> render_click()

    refute has_element?(view, "#variables-alpha_table_one input[value=Name][checked]")
  end

  test "emit_config pushes a config-ready event with JSON", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Alpha label input") |> render_click()
    view |> element("#emit-config-btn") |> render_click()

    assert_push_event(view, "config-ready", %{"json" => json})
    decoded = Jason.decode!(json)
    assert %{"tables" => tables} = decoded
    assert length(tables) == 2
  end

  test "emit_config omits disabled tables", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Alpha label input") |> render_click()

    # Disable table two
    view |> element("#table-alpha_table_two input[phx-click=toggle_table]") |> render_click()

    view |> element("#emit-config-btn") |> render_click()

    assert_push_event(view, "config-ready", %{"json" => json})
    decoded = Jason.decode!(json)
    ids = Enum.map(decoded["tables"], & &1["id"])
    assert ids == ["alpha_table_one"]
    refute "alpha_table_two" in ids
  end
end
