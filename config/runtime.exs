import Config

if config_env() == :prod do
  config :bot_army_outreach, BotArmyOutreach.Repo,
    username:
      System.get_env("BOT_ARMY_OUTREACH_DATABASE_USER") || System.get_env("DATABASE_USER") ||
        "bot_army",
    password:
      System.get_env("BOT_ARMY_OUTREACH_DATABASE_PASSWORD") || System.get_env("DATABASE_PASSWORD") ||
        "postgres",
    database:
      System.get_env("BOT_ARMY_OUTREACH_DATABASE_NAME") || System.get_env("DATABASE_NAME") ||
        "ergon_outreach",
    hostname:
      System.get_env("BOT_ARMY_OUTREACH_DATABASE_HOST") || System.get_env("DATABASE_HOST") ||
        "localhost",
    port:
      String.to_integer(
        System.get_env("BOT_ARMY_OUTREACH_DATABASE_PORT") || System.get_env("DATABASE_PORT") ||
          "5432"
      ),
    ssl:
      System.get_env("BOT_ARMY_OUTREACH_DATABASE_SSL") || System.get_env("DATABASE_SSL") ||
        "false" |> String.to_atom(),
    pool_size: String.to_integer(System.get_env("BOT_POOL_SIZE", "10"))
end
