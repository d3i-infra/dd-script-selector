defmodule DdScriptSelector.PlatformsCache do
  @moduledoc """
  GenServer that caches the platforms list at startup and refreshes it daily.
  """

  use GenServer

  alias DdScriptSelector.Platforms

  @refresh_interval :timer.hours(24)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Returns the cached list of platforms."
  def list do
    GenServer.call(__MODULE__, :list)
  end

  # ---------------------------------------------------------------------------
  # Callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(_opts) do
    platforms = Platforms.list()
    schedule_refresh()
    {:ok, platforms}
  end

  @impl true
  def handle_call(:list, _from, platforms) do
    {:reply, platforms, platforms}
  end

  @impl true
  def handle_info(:refresh, _platforms) do
    platforms = Platforms.list()
    schedule_refresh()
    {:noreply, platforms}
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end
end
