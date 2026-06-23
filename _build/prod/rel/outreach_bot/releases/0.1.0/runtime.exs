import Config

if config_env() == :prod do
  config :bot_army_outreach, BotArmyOutreach.Repo,
    username: System.fetch_env!("DB_USER"),
    password: System.fetch_env!("DB_PASSWORD"),
    database: System.fetch_env!("DB_NAME"),
    hostname: System.fetch_env!("DB_HOST"),
    port: String.to_integer(System.get_env("DB_PORT", "5432")),
    ssl: String.to_atom(System.get_env("DB_SSL", "false")),
    pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))
end
