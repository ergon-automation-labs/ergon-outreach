defmodule BotArmyOutreach.Stores.ContactStore do
  alias BotArmyOutreach.Repo
  alias BotArmyOutreach.Schemas.Contact
  import Ecto.Query

  def create_contact(attrs) do
    %Contact{}
    |> Contact.changeset(attrs)
    |> Repo.insert()
  end

  def get_contact(email) do
    Repo.get_by(Contact, email: email)
  end

  def get_contact!(id) do
    Repo.get!(Contact, id)
  end

  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> Contact.update_changeset(attrs)
    |> Repo.update()
  end

  def list_contacts(filters \\ []) do
    query = from(c in Contact)

    query =
      Enum.reduce(filters, query, fn
        {:stage, stage}, q ->
          where(q, [c], c.stage == ^stage)

        {:conversion_status, status}, q ->
          where(q, [c], c.conversion_status == ^status)

        {:needs_follow_up, true}, q ->
          now = DateTime.utc_now()
          where(q, [c], c.next_follow_up <= ^now and c.conversion_status == "open")

        _, q ->
          q
      end)

    Repo.all(query)
  end

  def stalled_contacts(days \\ 7) do
    cutoff = DateTime.add(DateTime.utc_now(), -days * 24 * 3600, :second)

    from(c in Contact,
      where: c.conversion_status == "open",
      where: is_nil(c.last_contact) or c.last_contact < ^cutoff,
      order_by: [asc: c.last_contact]
    )
    |> Repo.all()
  end

  def recent_replies do
    from(c in Contact,
      where: c.stage == "replied",
      where: c.updated_at > ago(7, "day"),
      order_by: [desc: c.updated_at]
    )
    |> Repo.all()
  end

  def conversion_stats do
    total = Repo.aggregate(Contact, :count, :id)
    deals = Repo.aggregate(from(c in Contact, where: c.conversion_status == "deal"), :count, :id)

    rejected =
      Repo.aggregate(from(c in Contact, where: c.conversion_status == "rejected"), :count, :id)

    open = Repo.aggregate(from(c in Contact, where: c.conversion_status == "open"), :count, :id)

    %{
      total: total,
      deals: deals,
      rejected: rejected,
      open: open,
      conversion_rate: if(total > 0, do: Float.round(deals / total * 100, 2), else: 0.0)
    }
  end
end
