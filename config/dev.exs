import Config

config :bot_army_outreach, BotArmyOutreach.Repo,
  username: "postgres",
  password: "postgres",
  database: "bot_army_outreach_dev",
  hostname: "localhost",
  port: 35432,
  show_sensitive_data_on_error: true,
  pool_size: 10
