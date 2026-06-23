defmodule BotArmyOutreach.Integrations.GoogleSheets do
  require Logger
  alias BotArmyOutreach.Stores.ContactStore

  @doc "Pull contacts from Google Sheet and upsert to database"
  def sync_from_sheet(sheet_id, range \\ "Contacts!A2:G") do
    case fetch_sheet_data(sheet_id, range) do
      {:ok, rows} ->
        Logger.info("Fetched #{Enum.count(rows)} rows from Google Sheet")
        upsert_contacts(rows, sheet_id)

      {:error, reason} ->
        Logger.error("Failed to fetch Google Sheet: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp fetch_sheet_data(sheet_id, range) do
    token = get_google_token()

    case token do
      nil ->
        {:error, :no_token}

      token ->
        url =
          "https://sheets.googleapis.com/v4/spreadsheets/#{sheet_id}/values/#{range}?key=#{System.get_env("GOOGLE_SHEETS_API_KEY")}"

        headers = [
          {"Authorization", "Bearer #{token}"},
          {"Content-Type", "application/json"}
        ]

        case Req.get(url, headers: headers) do
          {:ok, %{status: 200, body: body}} ->
            rows = Map.get(body, "values", [])
            {:ok, rows}

          {:error, reason} ->
            {:error, reason}

          {:ok, %{status: status}} ->
            {:error, "HTTP #{status}"}
        end
    end
  end

  defp get_google_token do
    System.get_env("GOOGLE_SHEETS_ACCESS_TOKEN")
  end

  defp upsert_contacts(rows, sheet_id) do
    results =
      Enum.map(rows, fn row ->
        case parse_contact_row(row, sheet_id) do
          {:ok, attrs} ->
            case ContactStore.get_contact(attrs["email"]) do
              nil ->
                ContactStore.create_contact(attrs)

              contact ->
                ContactStore.update_contact(contact, attrs)
            end

          {:error, reason} ->
            {:error, reason}
        end
      end)

    success_count = Enum.count(results, fn r -> match?({:ok, _}, r) end)
    error_count = Enum.count(results, fn r -> match?({:error, _}, r) end)

    Logger.info("Upserted #{success_count} contacts, #{error_count} errors")
    {:ok, %{success: success_count, errors: error_count}}
  end

  defp parse_contact_row(row, sheet_id) when is_list(row) do
    case row do
      [name, email, company, stage, last_contact, next_follow_up, notes] ->
        {:ok,
         %{
           "name" => name,
           "email" => email,
           "company" => company,
           "stage" => stage || "cold",
           "last_contact" => parse_date(last_contact),
           "next_follow_up" => parse_date(next_follow_up),
           "notes" => notes,
           "source_sheet_id" => sheet_id
         }}

      [name, email, company, stage, last_contact, next_follow_up] ->
        {:ok,
         %{
           "name" => name,
           "email" => email,
           "company" => company,
           "stage" => stage || "cold",
           "last_contact" => parse_date(last_contact),
           "next_follow_up" => parse_date(next_follow_up),
           "source_sheet_id" => sheet_id
         }}

      _ ->
        {:error, "Invalid row format"}
    end
  end

  defp parse_contact_row(_, _), do: {:error, "Row is not a list"}

  defp parse_date(nil), do: nil

  defp parse_date(""), do: nil

  defp parse_date(date_str) when is_binary(date_str) do
    case DateTime.from_iso8601(date_str) do
      {:ok, datetime, _} -> datetime
      :error -> try_parse_date_string(date_str)
    end
  end

  defp parse_date(_), do: nil

  defp try_parse_date_string(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      :error -> nil
    end
  end
end
