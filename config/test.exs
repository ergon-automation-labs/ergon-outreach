import Config

config :bot_army_outreach, BotArmyOutreach.Repo,
  username: "postgres",
  password: "postgres",
  database: "bot_army_outreach_test",
  hostname: "localhost",
  port: 35432,
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
