defmodule DdScriptSelectorWeb.ScriptSelectorLiveTest do
  # async: false because Application.put_env/3 is global state
  use DdScriptSelectorWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @fixture_alpha """
  \"\"\"
  Alpha platform module docstring.
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

  test "selecting a platform shows the detail panel with the docstring", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view
    |> element("#platform-Alpha label input")
    |> render_click()

    assert has_element?(view, "#detail-panel")
    assert has_element?(view, "#detail-panel h1", "Alpha")
    assert has_element?(view, "#detail-panel", "Alpha platform module docstring.")
    refute has_element?(view, "#detail-prompt")
  end

  test "the Build button is shown and enabled when a platform is selected", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view
    |> element("#platform-Beta label input")
    |> render_click()

    assert has_element?(view, "#detail-panel button", "Build")
    refute has_element?(view, "#detail-panel button[disabled]", "Build")
  end

  test "after clicking Build the spinner is gone and the button is re-enabled", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view
    |> element("#platform-Alpha label input")
    |> render_click()

    view
    |> element("#detail-panel button", "Build")
    |> render_click()

    # Process the :do_build message in the LiveView mailbox
    render(view)

    refute has_element?(view, ".loading-spinner")
    refute has_element?(view, "#detail-panel button[disabled]")
    assert has_element?(view, "#detail-panel button", "Build")
  end
end
