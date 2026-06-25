import Config

if config_env() == :prod do
  config :bot_army_outreach, BotArmyOutreach.Repo,
    username:
      System.get_env("BOT_ARMY_OUTREACH_DB_USER") || System.get_env("DB_USER") || "bot_army",
    password:
      System.get_env("BOT_ARMY_OUTREACH_DB_PASSWORD") || System.get_env("DB_PASSWORD") ||
        "bot_army_password",
    database:
      System.get_env("BOT_ARMY_OUTREACH_DB_NAME") || System.get_env("DB_NAME") || "ergon_outreach",
    hostname:
      System.get_env("BOT_ARMY_OUTREACH_DB_HOST") || System.get_env("DB_HOST") || "localhost",
    port:
      String.to_integer(
        System.get_env("BOT_ARMY_OUTREACH_DB_PORT") || System.get_env("DB_PORT") || "5432"
      ),
    ssl:
      System.get_env("BOT_ARMY_OUTREACH_DB_SSL") || System.get_env("DB_SSL") ||
        "false" |> String.to_atom(),
    pool_size: String.to_integer(System.get_env("BOT_POOL_SIZE", "10"))
end
