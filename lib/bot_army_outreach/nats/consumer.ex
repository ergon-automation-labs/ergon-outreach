defmodule BotArmyOutreach.NATS.Consumer do
  @moduledoc """
  NATS message consumer for outreach.

  Subscribes to NATS subjects and routes messages to handlers.
  Uses standardized Reply format for request/reply patterns.

  All request/reply handlers should return responses using Reply helpers:
  - BotArmyRuntime.NATS.Reply.ok(data) for success
  - BotArmyRuntime.NATS.Reply.error(message, code) for errors
  """

  use GenServer
  require Logger

  @reconnect_delay_ms 5000
  @version Mix.Project.config()[:version]

  alias BotArmyOutreach.Stores.ContactStore

  # Register subjects with their metadata for runtime discovery
  @subjects [
    %{subject: "outreach.contact.create", type: :request_reply, description: "Create a contact"},
    %{subject: "outreach.contact.update", type: :request_reply, description: "Update a contact"},
    %{subject: "outreach.contact.list", type: :request_reply, description: "List contacts"},
    %{
      subject: "outreach.follow_up.schedule",
      type: :request_reply,
      description: "Schedule a follow-up"
    },
    %{
      subject: "outreach.sheets.sync",
      type: :request_reply,
      description: "Pull contacts from Google Sheet"
    }
  ]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    Logger.info("Starting NATS consumer")

    state = %{
      subscriptions: [],
      conn: nil,
      opts: opts
    }

    {:ok, state, {:continue, :connect}}
  end

  @impl true
  def handle_continue(:connect, state) do
    case GenServer.call(BotArmyRuntime.NATS.Connection, :get_connection, 5000) do
      {:ok, conn} ->
        BotArmyRuntime.NATS.Connection.subscribe_to_status()
        Logger.info("Connected to NATS, subscribing to topics")

        subscriptions =
          [
            # Add your subjects here
          ]
          |> Enum.map(fn subject ->
            case Gnat.sub(conn, self(), subject) do
              {:ok, sub} ->
                Logger.info("Subscribed to #{subject}")
                sub

              {:error, reason} ->
                Logger.error("Failed to subscribe to #{subject}: #{inspect(reason)}")
                nil
            end
          end)
          |> Enum.filter(&(not is_nil(&1)))

        # Register subjects for runtime discovery
        BotArmyRuntime.Registry.register("outreach", @subjects, @version)

        {:noreply, %{state | subscriptions: subscriptions, conn: conn}}

      {:error, _reason} ->
        Logger.warning("NATS connection not ready, will retry")
        Process.send_after(self(), :connect_retry, @reconnect_delay_ms)
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(:connect_retry, state) do
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info({:msg, msg}, state) do
    BotArmyRuntime.Tracing.with_consumer_span(msg.topic, Map.get(msg, :headers), fn ->
      Logger.debug("Received NATS message on subject: #{msg.topic}")

      # Handle request/reply patterns
      if msg.reply_to do
        case msg.topic do
          "outreach.contact.create" -> handle_create_contact(msg, state)
          "outreach.contact.update" -> handle_update_contact(msg, state)
          "outreach.contact.list" -> handle_list_contacts(msg, state)
          "outreach.follow_up.schedule" -> handle_schedule_follow_up(msg, state)
          "outreach.sheets.sync" -> handle_sheets_sync(msg, state)
          _ -> Logger.debug("Unknown request/reply subject: #{msg.topic}")
        end
      else
        # Handle pub/sub messages
        case BotArmyCore.NATS.Decoder.decode(msg.body) do
          {:ok, decoded_message} ->
            route_message(decoded_message, msg.topic)

          {:error, reason} ->
            Logger.warning("Failed to decode message from #{msg.topic}: #{inspect(reason)}")
        end
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:nats, :disconnected}, state) do
    Logger.warning("Disconnected from NATS, will reconnect")
    Process.send_after(self(), :connect_retry, @reconnect_delay_ms)
    {:noreply, %{state | subscriptions: [], conn: nil}}
  end

  @impl true
  def handle_info({:nats, :connected}, state) do
    Logger.info("Reconnected to NATS, re-subscribing")
    {:noreply, state, {:continue, :connect}}
  end

  @impl true
  def handle_info(:reconnect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  # Message routing
  defp route_message(message, topic) do
    # Route decoded messages to appropriate handlers
    Logger.debug("Routing message from #{topic}")
  end

  # Request/reply handlers
  defp handle_create_contact(msg, state) do
    response =
      case Decoder.decode(msg.body) do
        {:ok, decoded} ->
          payload = decoded["payload"] || decoded

          case ContactStore.create_contact(payload) do
            {:ok, contact} ->
              BotArmyRuntime.NATS.Reply.ok(%{"contact" => contact})

            {:error, reason} ->
              BotArmyRuntime.NATS.Reply.error(inspect(reason), :create_failed)
          end

        {:error, reason} ->
          BotArmyRuntime.NATS.Reply.error(inspect(reason), :decode_failed)
      end

    if state.conn do
      Gnat.pub(state.conn, msg.reply_to, response)
    end
  end

  defp handle_update_contact(msg, state) do
    response =
      case Decoder.decode(msg.body) do
        {:ok, decoded} ->
          payload = decoded["payload"] || decoded

          case ContactStore.get_contact(payload["email"]) do
            nil ->
              BotArmyRuntime.NATS.Reply.error("Contact not found", :not_found)

            contact ->
              case ContactStore.update_contact(contact, payload) do
                {:ok, updated} ->
                  BotArmyRuntime.NATS.Reply.ok(%{"contact" => updated})

                {:error, reason} ->
                  BotArmyRuntime.NATS.Reply.error(inspect(reason), :update_failed)
              end
          end

        {:error, reason} ->
          BotArmyRuntime.NATS.Reply.error(inspect(reason), :decode_failed)
      end

    if state.conn do
      Gnat.pub(state.conn, msg.reply_to, response)
    end
  end

  defp handle_list_contacts(msg, state) do
    response =
      case Decoder.decode(msg.body) do
        {:ok, decoded} ->
          payload = decoded["payload"] || decoded
          filters = Map.get(payload, "filters", [])
          contacts = ContactStore.list_contacts(filters)
          BotArmyRuntime.NATS.Reply.ok(%{"contacts" => contacts})

        {:error, reason} ->
          BotArmyRuntime.NATS.Reply.error(inspect(reason), :decode_failed)
      end

    if state.conn do
      Gnat.pub(state.conn, msg.reply_to, response)
    end
  end

  defp handle_schedule_follow_up(msg, state) do
    response =
      case Decoder.decode(msg.body) do
        {:ok, decoded} ->
          payload = decoded["payload"] || decoded

          case ContactStore.get_contact(payload["email"]) do
            nil ->
              BotArmyRuntime.NATS.Reply.error("Contact not found", :not_found)

            contact ->
              follow_up_date =
                DateTime.add(
                  DateTime.utc_now(),
                  (payload["follow_up_in_days"] || 3) * 24 * 3600,
                  :second
                )

              case ContactStore.update_contact(contact, %{
                     next_follow_up: follow_up_date,
                     stage: "follow_up_scheduled"
                   }) do
                {:ok, updated} ->
                  BotArmyRuntime.NATS.Reply.ok(%{
                    "scheduled" => true,
                    "contact" => updated
                  })

                {:error, reason} ->
                  BotArmyRuntime.NATS.Reply.error(inspect(reason), :schedule_failed)
              end
          end

        {:error, reason} ->
          BotArmyRuntime.NATS.Reply.error(inspect(reason), :decode_failed)
      end

    if state.conn do
      Gnat.pub(state.conn, msg.reply_to, response)
    end
  end
end

  defp handle_sheets_sync(msg, state) do
    response =
      case Decoder.decode(msg.body) do
        {:ok, decoded} ->
          payload = decoded["payload"] || decoded
          sheet_id = payload["sheet_id"]
          range = payload["range"] || "Contacts!A2:G"

          case BotArmyOutreach.Integrations.GoogleSheets.sync_from_sheet(sheet_id, range) do
            {:ok, result} ->
              BotArmyRuntime.NATS.Reply.ok(result)

            {:error, reason} ->
              BotArmyRuntime.NATS.Reply.error(inspect(reason), :sync_failed)
          end

        {:error, reason} ->
          BotArmyRuntime.NATS.Reply.error(inspect(reason), :decode_failed)
      end

    if state.conn do
      Gnat.pub(state.conn, msg.reply_to, response)
    end
  end
