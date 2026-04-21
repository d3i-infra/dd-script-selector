defmodule DdScriptSelectorWeb.ScriptSelectorLiveTest do
  # async: false because Application.put_env/3 is global state
  use DdScriptSelectorWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  @fixture_alpha """
  \"\"\"
  Alpha platform module docstring.
  \"\"\"

  DEFAULT_TABLE_CONFIG_JSON: str = \"\"\"
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
    Application.put_env(:dd_script_selector, :builder_req_opts, plug: {Req.Test, :builder_api})

    on_exit(fn ->
      Application.delete_env(:dd_script_selector, :platforms_dir)
      Application.delete_env(:dd_script_selector, :builder_req_opts)
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

  test "selecting a platform shows the detail panel with name and docstring", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Alpha label input") |> render_click()

    assert has_element?(view, "#platform-Alpha", "Alpha")
  end

  test "selecting a platform with config shows table cards after advancing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")
    select_and_configure(view)

    assert has_element?(view, "#table-alpha_table_one")
    assert has_element?(view, "#table-alpha_table_two")
    assert has_element?(view, "#table-alpha_table_one", "Table One")
  end

  test "selecting a platform with two languages shows the language toggle", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")
    select_and_configure(view)

    assert has_element?(view, "#language-toggle")
    assert has_element?(view, "#language-toggle button", "en")
    assert has_element?(view, "#language-toggle button", "nl")
  end

  test "selecting a platform without config hides the language toggle", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")

    view |> element("#platform-Beta label input") |> render_click()
    view |> element("button[phx-click=next_step]") |> render_click()

    refute has_element?(view, "#language-toggle")
  end

  test "changing language updates table titles", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")
    select_and_configure(view)

    assert has_element?(view, "#table-alpha_table_one", "Table One")

    view |> element("#language-toggle button", "nl") |> render_click()

    assert has_element?(view, "#table-alpha_table_one", "Tabel Een")
  end

  test "toggle_table disables a table card", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")
    select_and_configure(view)

    assert has_element?(view, "#variables-alpha_table_one")

    view |> element("#table-alpha_table_one input[phx-click=toggle_table]") |> render_click()

    refute has_element?(view, "#variables-alpha_table_one")
  end

  test "toggle_variable removes a variable from the table", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/select")
    select_and_configure(view)

    assert has_element?(view, "#variables-alpha_table_one input[value=Name]")

    view
    |> element("#variables-alpha_table_one input[value=Name]")
    |> render_click()

    refute has_element?(view, "#variables-alpha_table_one input[value=Name][checked]")
  end

  test "emit_config starts a build with all enabled tables", %{conn: conn} do
    test_pid = self()

    Req.Test.stub(:builder_api, fn conn ->
      {:ok, body_bin, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:posted, Jason.decode!(body_bin)})
      Req.Test.json(conn, %{"build_id" => "uuid-all-tables"})
    end)

    {:ok, view, _html} = live(conn, ~p"/select")
    Req.Test.allow(:builder_api, self(), view.pid)
    select_and_configure(view)

    view |> element("#emit-config-btn") |> render_click()

    assert_receive {:posted, body}
    config = Jason.decode!(body["config"])
    assert length(config["tables"]) == 2
  end

  test "emit_config sends only enabled tables to builder API", %{conn: conn} do
    test_pid = self()

    Req.Test.stub(:builder_api, fn conn ->
      {:ok, body_bin, conn} = Plug.Conn.read_body(conn)
      send(test_pid, {:posted, Jason.decode!(body_bin)})
      Req.Test.json(conn, %{"build_id" => "uuid-filtered"})
    end)

    {:ok, view, _html} = live(conn, ~p"/select")
    Req.Test.allow(:builder_api, self(), view.pid)
    select_and_configure(view)

    view |> element("#table-alpha_table_two input[phx-click=toggle_table]") |> render_click()
    view |> element("#emit-config-btn") |> render_click()

    assert_receive {:posted, body}
    config = Jason.decode!(body["config"])
    ids = Enum.map(config["tables"], & &1["id"])
    assert ids == ["alpha_table_one"]
    refute "alpha_table_two" in ids
  end

  test "emit_config shows spinner while building", %{conn: conn} do
    Req.Test.stub(:builder_api, fn conn ->
      Req.Test.json(conn, %{"build_id" => "uuid-spinner"})
    end)

    {:ok, view, _html} = live(conn, ~p"/select")
    Req.Test.allow(:builder_api, self(), view.pid)
    select_and_configure(view)

    view |> element("#emit-config-btn") |> render_click()

    assert has_element?(view, "#build-spinner")
    refute has_element?(view, "#emit-config-btn")
  end

  test "polling a running build updates the log panel", %{conn: conn} do
    Req.Test.stub(:builder_api, fn conn ->
      case conn.request_path do
        "/build" ->
          Req.Test.json(conn, %{"build_id" => "uuid-poll"})

        "/status/uuid-poll" ->
          Req.Test.json(conn, %{"status" => "running", "logs" => ["Build started", "Repo copied"]})
      end
    end)

    {:ok, view, _html} = live(conn, ~p"/select")
    Req.Test.allow(:builder_api, self(), view.pid)
    select_and_configure(view)

    view |> element("#emit-config-btn") |> render_click()
    send(view.pid, :poll_build)
    render(view)

    assert has_element?(view, "#build-log-panel")
    assert has_element?(view, "#build-log-panel", "Build started")
    assert has_element?(view, "#build-log-panel", "Repo copied")
  end

  test "when build is done, pushes trigger-download-url and shows success banner", %{conn: conn} do
    Req.Test.stub(:builder_api, fn conn ->
      case conn.request_path do
        "/build" -> Req.Test.json(conn, %{"build_id" => "uuid-done"})
        "/status/uuid-done" -> Req.Test.json(conn, %{"status" => "done", "logs" => ["Done"]})
      end
    end)

    {:ok, view, _html} = live(conn, ~p"/select")
    Req.Test.allow(:builder_api, self(), view.pid)
    select_and_configure(view)

    view |> element("#emit-config-btn") |> render_click()
    send(view.pid, :poll_build)
    render(view)

    assert_push_event(view, "trigger-download-url", %{path: "/builds/uuid-done/download"})
    assert has_element?(view, "#build-status-banner", "Build complete")
  end

  test "build resets to idle after reset_build message", %{conn: conn} do
    Req.Test.stub(:builder_api, fn conn ->
      case conn.request_path do
        "/build" -> Req.Test.json(conn, %{"build_id" => "uuid-reset"})
        "/status/uuid-reset" -> Req.Test.json(conn, %{"status" => "done", "logs" => []})
      end
    end)

    {:ok, view, _html} = live(conn, ~p"/select")
    Req.Test.allow(:builder_api, self(), view.pid)
    select_and_configure(view)

    view |> element("#emit-config-btn") |> render_click()
    send(view.pid, :poll_build)
    render(view)

    send(view.pid, {:reset_build, "uuid-reset"})
    render(view)

    assert has_element?(view, "#emit-config-btn")
    refute has_element?(view, "#build-log-panel")
    refute has_element?(view, "#build-status-banner")
  end

  test "when poll returns error, shows error banner and re-enables emit button", %{conn: conn} do
    Req.Test.stub(:builder_api, fn conn ->
      case conn.request_path do
        "/build" -> Req.Test.json(conn, %{"build_id" => "uuid-err"})

        "/status/uuid-err" ->
          Req.Test.json(conn, %{
            "status" => "error",
            "logs" => ["ERROR: pnpm failed"],
            "error" => "pnpm build failed"
          })
      end
    end)

    {:ok, view, _html} = live(conn, ~p"/select")
    Req.Test.allow(:builder_api, self(), view.pid)
    select_and_configure(view)

    view |> element("#emit-config-btn") |> render_click()
    send(view.pid, :poll_build)
    render(view)

    assert has_element?(view, "#build-status-banner", "pnpm build failed")
    assert has_element?(view, "#emit-config-btn")
  end

  test "when builder API fails on emit, shows error immediately", %{conn: conn} do
    Req.Test.stub(:builder_api, fn conn ->
      Plug.Conn.send_resp(conn, 503, "service unavailable")
    end)

    {:ok, view, _html} = live(conn, ~p"/select")
    Req.Test.allow(:builder_api, self(), view.pid)
    select_and_configure(view)

    view |> element("#emit-config-btn") |> render_click()

    assert has_element?(view, "#build-status-banner", "Builder API unavailable")
    assert has_element?(view, "#emit-config-btn")
  end

  defp select_and_configure(view, platform \\ "Alpha") do
    view |> element("#platform-#{platform} label input") |> render_click()
    view |> element("button[phx-click=next_step]") |> render_click()
  end
end
