import Config

config :bot_army_outreach,
  ecto_repos: [BotArmyOutreach.Repo]

config :logger,
  level: :info,
  format: "$time $metadata[$level] $message\n"

import_config "#{Mix.env()}.exs"
