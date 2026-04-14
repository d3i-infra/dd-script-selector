# Emit Config → Build Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire up the "Emit config" button to POST the selected config to the dd-script-builder API, poll for build status with live log streaming, and auto-download the zip through Phoenix when the build completes.

**Architecture:** All builder API calls (`localhost:8000`) are proxied through Phoenix — the browser never communicates with the builder directly. The LiveView manages build state via assigns and `Process.send_after` polling. When done, a `push_event` triggers a JS handler that navigates to a Phoenix controller route, which proxies the zip back to the browser.

**Tech Stack:** Phoenix LiveView 1.1, Req 0.5 + Req.Test for HTTP mocking, Tailwind v4 / DaisyUI

---

## File Map

| File | Change |
|------|--------|
| `lib/dd_script_selector_web/controllers/build_controller.ex` | **Create** — proxies zip download from builder API |
| `lib/dd_script_selector_web/router.ex` | **Modify** — add `GET /builds/:id/download` |
| `lib/dd_script_selector_web/live/script_selector_live.ex` | **Modify** — build assigns, emit_config handler, poll_build, reset_build |
| `lib/dd_script_selector_web/live/script_selector_live.html.heex` | **Modify** — log panel, spinner button, success/error banners, auto-scroll hook |
| `assets/js/app.js` | **Modify** — `phx:trigger-download-url` event handler |
| `test/dd_script_selector_web/controllers/build_controller_test.exs` | **Create** — controller tests |
| `test/dd_script_selector_web/live/script_selector_live_test.exs` | **Modify** — new build flow tests, update stale emit_config tests |

---

## Task 1: BuildController — proxy zip download

**Files:**
- Create: `lib/dd_script_selector_web/controllers/build_controller.ex`
- Modify: `lib/dd_script_selector_web/router.ex`
- Create: `test/dd_script_selector_web/controllers/build_controller_test.exs`

- [ ] **Step 1.1: Write the failing tests**

Create `test/dd_script_selector_web/controllers/build_controller_test.exs`:

```elixir
defmodule DdScriptSelectorWeb.BuildControllerTest do
  use DdScriptSelectorWeb.ConnCase, async: false

  setup do
    Application.put_env(:dd_script_selector, :builder_req_opts,
      plug: {Req.Test, :builder_api}
    )

    on_exit(fn -> Application.delete_env(:dd_script_selector, :builder_req_opts) end)
    :ok
  end

  test "GET /builds/:id/download proxies zip from builder API", %{conn: conn} do
    Req.Test.stub(:builder_api, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/zip")
      |> Plug.Conn.send_resp(200, "fake-zip-bytes")
    end)

    conn = get(conn, "/builds/some-uuid/download")

    assert conn.status == 200
    assert get_resp_header(conn, "content-type") == ["application/zip"]
    assert get_resp_header(conn, "content-disposition") == [~s|attachment; filename="build.zip"|]
    assert conn.resp_body == "fake-zip-bytes"
  end

  test "GET /builds/:id/download returns 502 when builder API fails", %{conn: conn} do
    Req.Test.stub(:builder_api, fn conn ->
      Plug.Conn.send_resp(conn, 500, "error")
    end)

    conn = get(conn, "/builds/some-uuid/download")
    assert conn.status == 502
  end
end
```

- [ ] **Step 1.2: Run to confirm they fail**

```bash
mix test test/dd_script_selector_web/controllers/build_controller_test.exs
```

Expected: compile error or 2 failures (module/route not found).

- [ ] **Step 1.3: Create BuildController**

Create `lib/dd_script_selector_web/controllers/build_controller.ex`:

```elixir
defmodule DdScriptSelectorWeb.BuildController do
  use DdScriptSelectorWeb, :controller

  @builder_base "http://localhost:8000"

  def download(conn, %{"id" => id}) do
    case Req.get(@builder_base <> "/download/#{id}", builder_req_opts()) do
      {:ok, %{status: 200, body: body}} ->
        conn
        |> put_resp_content_type("application/zip")
        |> put_resp_header("content-disposition", ~s|attachment; filename="build.zip"|)
        |> send_resp(200, body)

      _ ->
        send_resp(conn, 502, "Build not available")
    end
  end

  defp builder_req_opts, do: Application.get_env(:dd_script_selector, :builder_req_opts, [])
end
```

- [ ] **Step 1.4: Add route**

In `lib/dd_script_selector_web/router.ex`, add inside the `scope "/", DdScriptSelectorWeb do` block:

```elixir
scope "/", DdScriptSelectorWeb do
  pipe_through :browser

  live "/", HomeLive
  live "/select", ScriptSelectorLive
  get "/builds/:id/download", BuildController, :download
end
```

- [ ] **Step 1.5: Run tests to confirm they pass**

```bash
mix test test/dd_script_selector_web/controllers/build_controller_test.exs
```

Expected: 2 tests, 0 failures.

- [ ] **Step 1.6: Commit**

```bash
git add lib/dd_script_selector_web/controllers/build_controller.ex \
        lib/dd_script_selector_web/router.ex \
        test/dd_script_selector_web/controllers/build_controller_test.exs
git commit -m "feat: add BuildController to proxy zip download from builder API"
```

---

## Task 2: JS trigger-download-url handler

**Files:**
- Modify: `assets/js/app.js`

- [ ] **Step 2.1: Add the event handler**

In `assets/js/app.js`, add after the existing `phx:trigger-download` block:

```javascript
// Trigger a file download via a server-push URL path.
// push_event("trigger-download-url", %{path: "/builds/id/download"})
window.addEventListener("phx:trigger-download-url", ({detail: {path}}) => {
  const a = document.createElement("a")
  a.href = path
  a.download = ""
  document.body.appendChild(a)
  a.click()
  document.body.removeChild(a)
})
```

- [ ] **Step 2.2: Commit**

```bash
git add assets/js/app.js
git commit -m "feat: add phx:trigger-download-url JS handler"
```

---

## Task 3: LiveView — add build assigns to mount

**Files:**
- Modify: `lib/dd_script_selector_web/live/script_selector_live.ex`

- [ ] **Step 3.1: Add build assigns to mount and module-level helpers**

In `lib/dd_script_selector_web/live/script_selector_live.ex`, update `mount/3` to add five new assigns at the end of the chain:

```elixir
def mount(_params, _session, socket) do
  platforms = Platforms.list()

  socket =
    socket
    |> assign(:platforms, platforms)
    |> assign(:platforms_by_name, Map.new(platforms, &{&1.name, &1}))
    |> assign(:step, :select_platform)
    |> assign(:selected, nil)
    |> assign(:selected_platform, nil)
    |> assign(:tables, [])
    |> assign(:language, "en")
    |> assign(:available_languages, [])
    |> assign(:title, "")
    |> assign(:editing_title, false)
    |> assign(:editing_table, nil)
    |> assign(:build_id, nil)
    |> assign(:build_status, nil)
    |> assign(:build_logs, [])
    |> assign(:build_error, nil)
    |> assign(:poll_retries, 0)

  {:ok, socket}
end
```

In the `# Private` section, add a module attribute and helper before the existing private functions:

```elixir
@builder_base "http://localhost:8000"

defp builder_req_opts, do: Application.get_env(:dd_script_selector, :builder_req_opts, [])
```

- [ ] **Step 3.2: Verify it compiles**

```bash
mix compile --warnings-as-errors
```

Expected: no errors.

- [ ] **Step 3.3: Commit**

```bash
git add lib/dd_script_selector_web/live/script_selector_live.ex
git commit -m "feat: add build assigns to ScriptSelectorLive mount"
```

---

## Task 4: emit_config handler — POST to builder API + spinner

**Files:**
- Modify: `lib/dd_script_selector_web/live/script_selector_live.ex`
- Modify: `lib/dd_script_selector_web/live/script_selector_live.html.heex`
- Modify: `test/dd_script_selector_web/live/script_selector_live_test.exs`

- [ ] **Step 4.1: Update the test setup block and add a navigation helper**

In `test/dd_script_selector_web/live/script_selector_live_test.exs`, update the `setup do` block:

```elixir
setup do
  tmp_dir =
    System.tmp_dir!()
    |> Path.join("script_selector_test_#{System.unique_integer([:positive])}")

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
```

Add a private helper function at the bottom of the test module (before the closing `end`):

```elixir
# Selects a platform and advances to the configure step.
# If the app uses a single-panel layout where the configurator is always visible,
# remove the `render_click()` on next_step.
defp select_and_configure(view, platform \\ "Alpha") do
  view |> element("#platform-#{platform} label input") |> render_click()
  view |> element("button[phx-click=next_step]") |> render_click()
end
```

- [ ] **Step 4.2: Write the failing test**

Add to the test module:

```elixir
test "emit_config POSTs to builder API and shows building spinner", %{conn: conn} do
  Req.Test.stub(:builder_api, fn conn ->
    Req.Test.json(conn, %{"build_id" => "uuid-task4"})
  end)

  {:ok, view, _html} = live(conn, ~p"/select")
  Req.Test.allow(:builder_api, self(), view.pid)
  select_and_configure(view)

  view |> element("#emit-config-btn") |> render_click()

  assert has_element?(view, "#build-spinner")
  refute has_element?(view, "#emit-config-btn")
end
```

- [ ] **Step 4.3: Run to confirm it fails**

```bash
mix test test/dd_script_selector_web/live/script_selector_live_test.exs
```

Expected: new test fails (`#build-spinner` not found).

- [ ] **Step 4.4: Replace emit_config handler in LiveView**

In `lib/dd_script_selector_web/live/script_selector_live.ex`, replace the existing `handle_event("emit_config", ...)` clause entirely:

```elixir
def handle_event("emit_config", _params, socket) do
  if valid_config?(socket.assigns.tables) do
    config_json = socket.assigns.tables |> build_config() |> Jason.encode!()

    result =
      Req.post(
        @builder_base <> "/build",
        [
          {:json,
           %{
             config: config_json,
             config_path: "port_config.json",
             output_dir: "releases"
           }}
          | builder_req_opts()
        ]
      )

    case result do
      {:ok, %{status: 200, body: %{"build_id" => build_id}}} ->
        Process.send_after(self(), :poll_build, 2_000)

        {:noreply,
         socket
         |> assign(:build_id, build_id)
         |> assign(:build_status, "queued")
         |> assign(:build_logs, [])
         |> assign(:build_error, nil)
         |> assign(:poll_retries, 0)}

      _ ->
        {:noreply,
         socket
         |> assign(:build_status, "error")
         |> assign(:build_error, "Builder API unavailable")}
    end
  else
    {:noreply, socket}
  end
end
```

- [ ] **Step 4.5: Update template — spinner button**

In `lib/dd_script_selector_web/live/script_selector_live.html.heex`, replace the entire `<%!-- Bottom action bar --%>` div at the bottom of the configure step with:

```heex
<%!-- Bottom action bar --%>
<div class="border-t border-base-300 p-4">
  <div class="flex justify-between items-center">
    <button
      phx-click="go_back"
      class={["btn btn-ghost", @build_status in ["queued", "running"] && "btn-disabled"]}
      disabled={@build_status in ["queued", "running"]}
    >
      ← Back
    </button>

    <button
      :if={@build_status not in ["queued", "running"]}
      id="emit-config-btn"
      phx-click="emit_config"
      class={["btn btn-primary", not valid_config?(@tables) && "btn-disabled"]}
      disabled={not valid_config?(@tables)}
    >
      Emit config
    </button>

    <button
      :if={@build_status in ["queued", "running"]}
      id="build-spinner"
      class="btn btn-primary btn-disabled"
      disabled
    >
      <span class="loading loading-spinner loading-sm"></span>
      Building…
    </button>
  </div>
</div>
```

- [ ] **Step 4.6: Run tests**

```bash
mix test test/dd_script_selector_web/live/script_selector_live_test.exs
```

Expected: new test passes. The two old `emit_config` tests that expect `config-ready` push event will now fail — that is expected and is fixed in Task 8.

- [ ] **Step 4.7: Commit**

```bash
git add lib/dd_script_selector_web/live/script_selector_live.ex \
        lib/dd_script_selector_web/live/script_selector_live.html.heex \
        test/dd_script_selector_web/live/script_selector_live_test.exs
git commit -m "feat: emit_config calls builder API and shows spinner while building"
```

---

## Task 5: Polling — handle_info(:poll_build) + log panel

**Files:**
- Modify: `lib/dd_script_selector_web/live/script_selector_live.ex`
- Modify: `lib/dd_script_selector_web/live/script_selector_live.html.heex`
- Modify: `test/dd_script_selector_web/live/script_selector_live_test.exs`

- [ ] **Step 5.1: Write the failing test**

Add to the test module:

```elixir
test "polling a running build updates the log panel", %{conn: conn} do
  Req.Test.stub(:builder_api, fn conn ->
    case conn.request_path do
      "/build" ->
        Req.Test.json(conn, %{"build_id" => "uuid-task5"})

      "/status/uuid-task5" ->
        Req.Test.json(conn, %{
          "status" => "running",
          "logs" => ["Build started", "Repo copied"]
        })
    end
  end)

  {:ok, view, _html} = live(conn, ~p"/select")
  Req.Test.allow(:builder_api, self(), view.pid)
  select_and_configure(view)

  view |> element("#emit-config-btn") |> render_click()

  # Trigger poll directly — no need to wait for the 2s timer
  send(view.pid, :poll_build)
  render(view)

  assert has_element?(view, "#build-log-panel")
  assert has_element?(view, "#build-log-panel", "Build started")
  assert has_element?(view, "#build-log-panel", "Repo copied")
end
```

- [ ] **Step 5.2: Run to confirm it fails**

```bash
mix test test/dd_script_selector_web/live/script_selector_live_test.exs
```

Expected: new test fails (`#build-log-panel` not found).

- [ ] **Step 5.3: Add handle_info(:poll_build) to LiveView**

In `lib/dd_script_selector_web/live/script_selector_live.ex`, add after all the `handle_event` clauses and before the `# Private` comment:

```elixir
def handle_info(:poll_build, socket) do
  build_id = socket.assigns.build_id

  case Req.get(@builder_base <> "/status/#{build_id}", builder_req_opts()) do
    {:ok, %{status: 200, body: body}} ->
      status = body["status"]
      logs = body["logs"] || []

      socket =
        socket
        |> assign(:build_status, status)
        |> assign(:build_logs, logs)
        |> assign(:poll_retries, 0)

      socket =
        case status do
          s when s in ["queued", "running"] ->
            Process.send_after(self(), :poll_build, 2_000)
            socket

          "done" ->
            Process.send_after(self(), {:reset_build, build_id}, 2_000)

            push_event(socket, "trigger-download-url", %{
              path: "/builds/#{build_id}/download"
            })

          "error" ->
            assign(socket, :build_error, body["error"] || "Unknown build error")

          _ ->
            socket
        end

      {:noreply, socket}

    {:error, _} ->
      retries = socket.assigns.poll_retries + 1

      if retries > 3 do
        {:noreply,
         socket
         |> assign(:build_status, "error")
         |> assign(:build_error, "Lost connection to builder API")}
      else
        Process.send_after(self(), :poll_build, 2_000)
        {:noreply, assign(socket, :poll_retries, retries)}
      end
  end
end

def handle_info({:reset_build, build_id}, socket) do
  if socket.assigns.build_id == build_id do
    {:noreply,
     socket
     |> assign(:build_id, nil)
     |> assign(:build_status, nil)
     |> assign(:build_logs, [])
     |> assign(:build_error, nil)
     |> assign(:poll_retries, 0)}
  else
    {:noreply, socket}
  end
end
```

- [ ] **Step 5.4: Add log panel to template**

In `lib/dd_script_selector_web/live/script_selector_live.html.heex`, inside the configure step `<div :if={@step == :configure} ...>`, add the following just before the `<%!-- Bottom action bar --%>` comment:

```heex
<%!-- Build log panel — visible whenever a build is in progress or finished --%>
<div
  :if={@build_status != nil}
  id="build-log-panel"
  class="border-t border-base-300 bg-base-200 max-h-48 overflow-y-auto p-4 font-mono text-xs"
  phx-hook=".AutoScroll"
>
  <p :for={line <- @build_logs} class="leading-5">{line}</p>
</div>

<script :type={Phoenix.LiveView.ColocatedHook} name=".AutoScroll">
  export default {
    updated() {
      this.el.scrollTop = this.el.scrollHeight
    }
  }
</script>
```

- [ ] **Step 5.5: Run tests**

```bash
mix test test/dd_script_selector_web/live/script_selector_live_test.exs
```

Expected: new polling test passes.

- [ ] **Step 5.6: Commit**

```bash
git add lib/dd_script_selector_web/live/script_selector_live.ex \
        lib/dd_script_selector_web/live/script_selector_live.html.heex \
        test/dd_script_selector_web/live/script_selector_live_test.exs
git commit -m "feat: add poll_build handle_info with live log panel"
```

---

## Task 6: Done state — success banner

**Files:**
- Modify: `lib/dd_script_selector_web/live/script_selector_live.html.heex`
- Modify: `test/dd_script_selector_web/live/script_selector_live_test.exs`

- [ ] **Step 6.1: Write failing tests**

Add to the test module:

```elixir
test "when build is done, pushes trigger-download-url event and shows success banner", %{conn: conn} do
  Req.Test.stub(:builder_api, fn conn ->
    case conn.request_path do
      "/build" -> Req.Test.json(conn, %{"build_id" => "uuid-task6"})
      "/status/uuid-task6" -> Req.Test.json(conn, %{"status" => "done", "logs" => ["Done"]})
    end
  end)

  {:ok, view, _html} = live(conn, ~p"/select")
  Req.Test.allow(:builder_api, self(), view.pid)
  select_and_configure(view)

  view |> element("#emit-config-btn") |> render_click()
  send(view.pid, :poll_build)
  render(view)

  assert_push_event(view, "trigger-download-url", %{"path" => "/builds/uuid-task6/download"})
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
```

- [ ] **Step 6.2: Run to confirm they fail**

```bash
mix test test/dd_script_selector_web/live/script_selector_live_test.exs
```

Expected: both new tests fail (`#build-status-banner` not found).

- [ ] **Step 6.3: Add success banner to template**

In `lib/dd_script_selector_web/live/script_selector_live.html.heex`, inside the bottom action bar `<div class="border-t border-base-300 p-4">`, add banners between the outer div and the `<div class="flex justify-between ...">` row:

```heex
<%!-- Build status banners --%>
<div
  :if={@build_status == "done"}
  id="build-status-banner"
  class="mb-3 flex items-center gap-2 rounded-lg bg-success/10 px-4 py-2 text-success text-sm font-medium"
>
  <.icon name="hero-check-circle" class="h-5 w-5 shrink-0" />
  Build complete — downloading…
</div>
```

- [ ] **Step 6.4: Run tests**

```bash
mix test test/dd_script_selector_web/live/script_selector_live_test.exs
```

Expected: both new tests pass.

- [ ] **Step 6.5: Commit**

```bash
git add lib/dd_script_selector_web/live/script_selector_live.html.heex \
        test/dd_script_selector_web/live/script_selector_live_test.exs
git commit -m "feat: show success banner when build done, auto-reset after 2s"
```

---

## Task 7: Error state — error banner + button re-enabled

**Files:**
- Modify: `lib/dd_script_selector_web/live/script_selector_live.html.heex`
- Modify: `test/dd_script_selector_web/live/script_selector_live_test.exs`

- [ ] **Step 7.1: Write failing tests**

Add to the test module:

```elixir
test "when poll returns error, shows error banner and re-enables emit button", %{conn: conn} do
  Req.Test.stub(:builder_api, fn conn ->
    case conn.request_path do
      "/build" -> Req.Test.json(conn, %{"build_id" => "uuid-error"})

      "/status/uuid-error" ->
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

test "when builder API returns an error on emit, shows error immediately", %{conn: conn} do
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
```

- [ ] **Step 7.2: Run to confirm they fail**

```bash
mix test test/dd_script_selector_web/live/script_selector_live_test.exs
```

Expected: both tests fail (`#build-status-banner` with error text not found, or element absent).

- [ ] **Step 7.3: Add error banner to template**

In `lib/dd_script_selector_web/live/script_selector_live.html.heex`, inside the bottom action bar, add the error banner directly after the done banner from Task 6:

```heex
<div
  :if={@build_status == "error"}
  id="build-status-banner"
  class="mb-3 flex items-center gap-2 rounded-lg bg-error/10 px-4 py-2 text-error text-sm font-medium"
>
  <.icon name="hero-x-circle" class="h-5 w-5 shrink-0" />
  Build failed: {@build_error}
</div>
```

- [ ] **Step 7.4: Run tests**

```bash
mix test test/dd_script_selector_web/live/script_selector_live_test.exs
```

Expected: both new error tests pass.

- [ ] **Step 7.5: Commit**

```bash
git add lib/dd_script_selector_web/live/script_selector_live.html.heex \
        test/dd_script_selector_web/live/script_selector_live_test.exs
git commit -m "feat: show error banner on build failure and re-enable emit button"
```

---

## Task 8: Update stale existing emit_config tests

**Files:**
- Modify: `test/dd_script_selector_web/live/script_selector_live_test.exs`

The two existing tests that call `view |> element("#emit-config-btn") |> render_click()` without navigating to the configure step, and then assert `push_event(view, "config-ready", ...)`, are now broken because:
1. `#emit-config-btn` is only rendered in the configure step (`@step == :configure`).
2. The `emit_config` handler no longer pushes a `config-ready` event.

Replace both tests:

- [ ] **Step 8.1: Remove the two stale tests**

Delete from the test file:

```elixir
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
```

- [ ] **Step 8.2: Add replacement tests**

```elixir
test "emit_config starts a build with all enabled tables", %{conn: conn} do
  test_pid = self()

  Req.Test.stub(:builder_api, fn conn ->
    {:ok, body_bin, conn} = Plug.Conn.read_body(conn)
    send(test_pid, {:posted, Jason.decode!(body_bin)})
    Req.Test.json(conn, %{"build_id" => "uuid-stale1"})
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
    Req.Test.json(conn, %{"build_id" => "uuid-stale2"})
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
```

- [ ] **Step 8.3: Run all tests**

```bash
mix test
```

Expected: all tests pass.

- [ ] **Step 8.4: Run precommit checks**

```bash
mix precommit
```

Expected: compile OK, format OK, all tests pass, no unused deps.

- [ ] **Step 8.5: Commit**

```bash
git add test/dd_script_selector_web/live/script_selector_live_test.exs
git commit -m "test: update stale emit_config tests for builder API flow"
```
