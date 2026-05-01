defmodule DdScriptSelectorWeb.Router do
  use DdScriptSelectorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {DdScriptSelectorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :configure_framing_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  defp configure_framing_headers(conn, _opts) do
    conn
    |> Plug.Conn.delete_resp_header("x-frame-options")
    |> Plug.Conn.delete_resp_header("content-security-policy")
  end

  scope "/", DdScriptSelectorWeb do
    pipe_through :browser
    live "/", HomeLive
    live "/select", ScriptSelectorLive
    get "/builds/:id/download", BuildController, :download
  end

  if Application.compile_env(:dd_script_selector, :dev_routes) do
    import Phoenix.LiveDashboard.Router
    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: DdScriptSelectorWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
