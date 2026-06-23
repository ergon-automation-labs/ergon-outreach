defmodule BotArmyOutreach.Workers.FollowUpScheduler do
  use GenServer
  require Logger

  alias BotArmyOutreach.Stores.ContactStore

  @check_interval :timer.minutes(30)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    schedule_check()
    {:ok, %{}}
  end

  @impl true
  def handle_info(:check_follow_ups, state) do
    check_and_schedule_follow_ups()
    schedule_check()
    {:noreply, state}
  end

  defp schedule_check do
    Process.send_after(self(), :check_follow_ups, @check_interval)
  end

  defp check_and_schedule_follow_ups do
    try do
      contacts = ContactStore.list_contacts(needs_follow_up: true)

      Enum.each(contacts, fn contact ->
        create_gtd_project(contact)
      end)

      Logger.info("Checked #{Enum.count(contacts)} contacts needing follow-up")
    rescue
      e ->
        Logger.error("Error in follow-up scheduler: #{inspect(e)}")
    end
  end

  defp create_gtd_project(contact) do
    task_title = "Follow up: #{contact.name}"

    task_description = """
    **Contact:** #{contact.name}
    **Company:** #{contact.company}
    **Email:** #{contact.email}
    **Stage:** #{contact.stage}
    **Last Contact:** #{format_datetime(contact.last_contact)}
    **Notes:** #{contact.notes || "N/A"}

    ## Subtasks
    - [ ] Review context from last email
    - [ ] Compose follow-up message
    - [ ] Send follow-up
    - [ ] Update contact stage

    **Next Follow-up:** #{format_datetime(contact.next_follow_up)}
    """

    case bridge_create_task(task_title, task_description, contact.id) do
      {:ok, task_id} ->
        Logger.info("Created GTD task #{task_id} for follow-up: #{contact.name}")

      {:error, reason} ->
        Logger.error("Failed to create GTD task for #{contact.name}: #{inspect(reason)}")
    end
  end

  defp bridge_create_task(title, description, contact_id) do
    payload = %{
      "title" => title,
      "description" => description,
      "project" => "Outreach",
      "metadata" => %{
        "contact_id" => contact_id,
        "source" => "outreach_bot"
      }
    }

    case Gnat.request(:gnat, "bridge.task.create", Jason.encode!(payload), receive_timeout: 5000) do
      {:ok, reply} ->
        case Jason.decode(reply.body) do
          {:ok, %{"ok" => true, "data" => %{"id" => task_id}}} ->
            {:ok, task_id}

          {:ok, %{"ok" => false, "error" => error}} ->
            {:error, error}

          _ ->
            {:error, "Invalid response"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_datetime(nil), do: "Never"

  defp format_datetime(datetime) do
    DateTime.to_iso8601(datetime)
  end
end
