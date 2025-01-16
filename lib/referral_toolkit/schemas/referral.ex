defmodule ReferralToolkit.Schemas.Referral do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias ReferralToolkit.Config

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "referral_toolkit_referrals" do
    belongs_to(:referral_code, ReferralToolkit.Schemas.ReferralCode)
    field(:applicant_id, Config.applicant_id_schema_type())
    field(:status, Ecto.Enum, values: [:pending, :completed, :expired])
    field(:completed_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(referral, attrs) do
    referral
    |> cast(attrs, [:referral_code_id, :applicant_id, :status, :completed_at])
    |> validate_required([:referral_code_id, :applicant_id, :status])
    |> validate_status_transition()
    |> foreign_key_constraint(:referral_code_id)
  end

  defp validate_status_transition(changeset) do
    case {changeset.data.status, get_change(changeset, :status)} do
      {old, new} when old == :completed and new != :completed ->
        add_error(changeset, :status, "Cannot change status once completed")

      {old, new} when old == :expired and new not in [:expired] ->
        add_error(changeset, :status, "Cannot change status once expired")

      _ ->
        changeset
    end
  end
end
