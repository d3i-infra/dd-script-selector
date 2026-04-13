defmodule DdScriptSelectorWeb.ScriptSelectorLive do
  use DdScriptSelectorWeb, :live_view

  alias DdScriptSelector.Platforms

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

    {:ok, socket}
  end

  def handle_event("select", %{"name" => name}, socket) do
    platform = socket.assigns.platforms_by_name[name]

    socket =
      socket
      |> assign(:selected, name)
      |> assign(:selected_platform, platform)
      |> assign(:tables, platform.tables)
      |> assign(:language, "en")
      |> assign(:available_languages, platform.available_languages)
      |> assign(:title, name)

    {:noreply, socket}
  end

  def handle_event("next_step", _params, socket) do
    if socket.assigns.selected do
      {:noreply, assign(socket, :step, :configure)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("go_back", _params, socket) do
    {:noreply,
     socket
     |> assign(:step, :select_platform)
     |> assign(:editing_title, false)
     |> assign(:editing_table, nil)}
  end

  def handle_event("edit_title", _params, socket) do
    {:noreply, assign(socket, :editing_title, true)}
  end

  def handle_event("save_title", %{"title" => title}, socket) do
    {:noreply, socket |> assign(:title, title) |> assign(:editing_title, false)}
  end

  def handle_event("cancel_edit_title", _params, socket) do
    {:noreply, assign(socket, :editing_title, false)}
  end

  def handle_event("edit_table_field", %{"table_id" => table_id, "field" => field}, socket) do
    {:noreply, assign(socket, :editing_table, {table_id, field})}
  end

  def handle_event(
        "save_table_field",
        %{"table_id" => table_id, "field" => field, "value" => value},
        socket
      ) do
    lang = socket.assigns.language

    tables =
      Enum.map(socket.assigns.tables, fn table ->
        if table.id == table_id do
          case field do
            "title" -> %{table | title: Map.put(table.title, lang, value)}
            "description" -> %{table | description: Map.put(table.description, lang, value)}
            _ -> table
          end
        else
          table
        end
      end)

    {:noreply, socket |> assign(:tables, tables) |> assign(:editing_table, nil)}
  end

  def handle_event("cancel_edit_table_field", _params, socket) do
    {:noreply, assign(socket, :editing_table, nil)}
  end

  def handle_event("toggle_table", %{"id" => id}, socket) do
    tables =
      Enum.map(socket.assigns.tables, fn table ->
        if table.id == id, do: %{table | enabled: !table.enabled}, else: table
      end)

    {:noreply, assign(socket, :tables, tables)}
  end

  def handle_event("toggle_variable", %{"table_id" => table_id, "key" => key}, socket) do
    tables =
      Enum.map(socket.assigns.tables, fn table ->
        if table.id == table_id do
          enabled_headers =
            if key in table.enabled_headers do
              List.delete(table.enabled_headers, key)
            else
              table.enabled_headers ++ [key]
            end

          %{table | enabled_headers: enabled_headers}
        else
          table
        end
      end)

    {:noreply, assign(socket, :tables, tables)}
  end

  def handle_event("select_all_tables", _params, socket) do
    tables = Enum.map(socket.assigns.tables, &%{&1 | enabled: true})
    {:noreply, assign(socket, :tables, tables)}
  end

  def handle_event("deselect_all_tables", _params, socket) do
    tables = Enum.map(socket.assigns.tables, &%{&1 | enabled: false})
    {:noreply, assign(socket, :tables, tables)}
  end

  def handle_event("select_all_variables", %{"table_id" => table_id}, socket) do
    tables =
      Enum.map(socket.assigns.tables, fn table ->
        if table.id == table_id do
          %{table | enabled_headers: table.headers |> Map.keys() |> Enum.sort()}
        else
          table
        end
      end)

    {:noreply, assign(socket, :tables, tables)}
  end

  def handle_event("deselect_all_variables", %{"table_id" => table_id}, socket) do
    tables =
      Enum.map(socket.assigns.tables, fn table ->
        if table.id == table_id, do: %{table | enabled_headers: []}, else: table
      end)

    {:noreply, assign(socket, :tables, tables)}
  end

  def handle_event("change_language", %{"lang" => lang}, socket) do
    {:noreply, assign(socket, :language, lang)}
  end

  def handle_event("emit_config", _params, socket) do
    if valid_config?(socket.assigns.tables) do
      json = socket.assigns.tables |> build_config() |> Jason.encode!()
      IO.inspect(json)
      {:noreply, push_event(socket, "config-ready", %{"json" => json})}
    else
      {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp valid_config?(tables) do
    has_enabled_table?(tables) and all_enabled_tables_have_variables?(tables)
  end

  defp has_enabled_table?(tables) do
    Enum.any?(tables, & &1.enabled)
  end

  defp all_enabled_tables_have_variables?(tables) do
    tables
    |> Enum.filter(& &1.enabled)
    |> Enum.all?(fn t -> length(t.enabled_headers) > 0 end)
  end

  defp build_config(tables) do
    enabled_tables =
      tables
      |> Enum.filter(& &1.enabled)
      |> Enum.map(fn table ->
        filtered_headers =
          Map.filter(table.headers, fn {key, _} -> key in table.enabled_headers end)

        %{
          "id" => table.id,
          "extractor" => table.extractor,
          "title" => table.title,
          "description" => table.description,
          "headers" => filtered_headers,
          "extractor_kwargs" => table.extractor_kwargs,
          "visualizations" => table.visualizations,
          "variables" => table.enabled_headers
        }
      end)

    %{"tables" => enabled_tables}
  end
end
