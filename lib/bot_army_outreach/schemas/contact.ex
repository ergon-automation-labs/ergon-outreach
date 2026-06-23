defmodule BotArmyOutreach.Schemas.Contact do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "contacts" do
    field(:name, :string)
    field(:email, :string)
    field(:company, :string)
    field(:stage, :string, default: "cold")
    field(:last_contact, :utc_datetime)
    field(:next_follow_up, :utc_datetime)
    field(:notes, :string)
    field(:source_sheet_id, :string)
    field(:response_count, :integer, default: 0)
    field(:first_contact_date, :utc_datetime)
    field(:conversion_status, :string, default: "open")

    timestamps(type: :utc_datetime)
  end

  def changeset(contact, attrs) do
    contact
    |> cast(attrs, [
      :name,
      :email,
      :company,
      :stage,
      :last_contact,
      :next_follow_up,
      :notes,
      :source_sheet_id,
      :response_count,
      :first_contact_date,
      :conversion_status
    ])
    |> validate_required([:name, :email, :stage])
    |> unique_constraint(:email)
  end

  def update_changeset(contact, attrs) do
    contact
    |> changeset(attrs)
    |> put_change(:updated_at, DateTime.utc_now(:millisecond))
  end
end
