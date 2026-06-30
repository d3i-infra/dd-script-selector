defmodule DdScriptSelector.PlatformsCache do
  @moduledoc """
  GenServer that caches the platforms list at startup and refreshes it daily.

  Starts immediately with an error state. Platform loading happens in a
  background Task so the server is never blocked. Connected LiveViews are
  notified via PubSub when platforms become available.
  """

  use GenServer

  alias DdScriptSelector.Platforms

  @pubsub DdScriptSelector.PubSub
  @topic "platforms_cache"

  @refresh_interval :timer.hours(24)
  @retry_interval :timer.minutes(1)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns `{:ok, platforms}` or `{:error, :init_failed}` when the builder API is unavailable or returned invalid data."
  def list do
    GenServer.call(__MODULE__, :list)
  end

  @doc "PubSub topic to subscribe to for platform availability updates."
  def topic, do: @topic

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    spawn_load()
    {:ok, %{status: :error, platforms: []}}
  end

  @impl true
  def handle_call(:list, _from, %{status: :ok, platforms: platforms} = state) do
    {:reply, {:ok, platforms}, state}
  end

  def handle_call(:list, _from, %{status: :error} = state) do
    {:reply, {:error, :init_failed}, state}
  end

  @impl true
  def handle_cast({:loaded, state}, _old) do
    if state.status == :ok do
      Phoenix.PubSub.broadcast(@pubsub, @topic, :platforms_available)
    end

    schedule_refresh(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:refresh, _state) do
    spawn_load()
    {:noreply, %{status: :error, platforms: []}}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp spawn_load do
    server = self()

    Task.start(fn ->
      state = load_platforms()
      GenServer.cast(server, {:loaded, state})
    end)
  end

  defp load_platforms do
    configured = Application.fetch_env!(:dd_script_selector, :platforms)

    platforms =
      try do
        Platforms.list()
      rescue
        _ -> []
      end

    if length(platforms) < length(configured) do
      %{status: :error, platforms: []}
    else
      %{status: :ok, platforms: platforms}
    end
  end

  defp schedule_refresh(%{status: :error}) do
    Process.send_after(self(), :refresh, @retry_interval)
  end

  defp schedule_refresh(%{status: :ok}) do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
end
