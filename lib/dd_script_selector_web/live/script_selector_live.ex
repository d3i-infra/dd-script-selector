defmodule DdScriptSelectorWeb.ScriptSelectorLive do
  use DdScriptSelectorWeb, :live_view

  alias DdScriptSelector.Platforms

  def mount(_params, _session, socket) do
    platforms = Platforms.list()

    socket =
      socket
      |> stream(:platforms, platforms, dom_id: &"platform-#{&1.name}")
      |> assign(:platforms_by_name, Map.new(platforms, &{&1.name, &1}))
      |> assign(:selected, nil)
      |> assign(:selected_platform, nil)
      |> assign(:building, false)

    {:ok, socket}
  end

  def handle_event("select", %{"name" => name}, socket) do
    platform = socket.assigns.platforms_by_name[name]
    {:noreply, assign(socket, selected: name, selected_platform: platform)}
  end

  def handle_event("build", _params, socket) do
    send(self(), :do_build)
    {:noreply, assign(socket, :building, true)}
  end

  def handle_info(:do_build, socket) do
    content = "placeholder zip content"

    socket =
      push_event(socket, "trigger-download", %{
        filename: "script.zip",
        content: Base.encode64(content)
      })

    socket = assign(socket, :building, false)
    {:noreply, socket}
  end
end
