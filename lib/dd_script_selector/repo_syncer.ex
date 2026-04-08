defmodule DdScriptSelector.RepoSyncer do
  @moduledoc """
  Periodically clones the data-donation-task repository to a local directory.

  On startup it immediately performs a clone, then repeats every 24 hours.
  Each run removes the existing clone directory (if present) before cloning,
  so the local copy is always a fresh checkout of the default branch.

  ## Configuration

      config :dd_script_selector, :repo_syncer_opts,
        repo_url: "https://github.com/d3i-infra/data-donation-task",
        target_dir: "repos/data-donation-task"

  Both keys are optional; the values shown above are the defaults.
  """

  use GenServer
  require Logger

  @repo_url "https://github.com/d3i-infra/data-donation-task"
  @interval :timer.hours(24)

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Returns the default local directory used when no `target_dir` opt is given.
  """
  def clone_dir do
    Path.expand("../../repos/data-donation-task", __DIR__)
  end

  @doc """
  Clones `repo_url` into `target_dir`, removing any prior clone first.
  Returns `:ok` on success or `{:error, output}` on failure.
  """
  def sync(repo_url, target_dir) do
    File.mkdir_p!(Path.dirname(target_dir))

    if File.exists?(target_dir), do: File.rm_rf!(target_dir)

    Logger.info("RepoSyncer: cloning #{repo_url} → #{target_dir}")

    case System.cmd("git", ["clone", repo_url, target_dir], stderr_to_stdout: true) do
      {_output, 0} ->
        Logger.info("RepoSyncer: clone successful")
        :ok

      {output, exit_code} ->
        Logger.error("RepoSyncer: clone failed (exit #{exit_code})\n#{output}")
        {:error, output}
    end
  end

  # ---------------------------------------------------------------------------
  # GenServer callbacks
  # ---------------------------------------------------------------------------

  @impl true
  def init(opts) do
    repo_url = Keyword.get(opts, :repo_url, @repo_url)
    target_dir = Keyword.get(opts, :target_dir, clone_dir())
    send(self(), :sync)
    {:ok, %{repo_url: repo_url, target_dir: target_dir}}
  end

  @impl true
  def handle_info(:sync, %{repo_url: repo_url, target_dir: target_dir} = state) do
    sync(repo_url, target_dir)
    Process.send_after(self(), :sync, @interval)
    {:noreply, state}
  end
end
