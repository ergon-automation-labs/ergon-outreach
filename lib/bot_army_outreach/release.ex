defmodule BotArmyOutreach.Release do
  @moduledoc "Runtime release tasks for outreach bot"
  
  def migrate do
    require Logger
    
    for repo <- repos() do
      {:ok, _fun_return, _apps} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  defp repos do
    Application.load(:bot_army_outreach)
    Application.fetch_env!(:bot_army_outreach, :ecto_repos)
  end
end
