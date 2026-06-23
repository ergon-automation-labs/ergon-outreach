defmodule BotArmyOutreach.Repo.Migrations.CreateContacts do
  use Ecto.Migration

  def change do
    create table(:contacts, primary_key: [name: :id, type: :binary_id]) do
      add(:name, :string, null: false)
      add(:email, :string, null: false)
      add(:company, :string)
      add(:stage, :string, null: false, default: "cold")
      add(:last_contact, :utc_datetime)
      add(:next_follow_up, :utc_datetime)
      add(:notes, :text)
      add(:source_sheet_id, :string)
      add(:response_count, :integer, default: 0)
      add(:first_contact_date, :utc_datetime)
      add(:conversion_status, :string, default: "open")

      timestamps(type: :utc_datetime)
    end

    create(unique_index(:contacts, [:email]))
    create(index(:contacts, [:stage]))
    create(index(:contacts, [:next_follow_up]))
    create(index(:contacts, [:conversion_status]))
  end
end
