defmodule ReferralToolkit.Schemas.ReferralCode do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias ReferralToolkit.Config

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "referral_toolkit_codes" do
    field(:code, :string)
    field(:promoter_id, Config.promoter_id_schema_type())
    field(:active, :boolean, default: true)
    field(:max_uses, :integer)
    field(:current_uses, :integer, default: 0)
    field(:expires_at, :utc_datetime_usec)
    has_many(:referrals, ReferralToolkit.Schemas.Referral)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(referral_code, attrs) do
    referral_code
    |> cast(attrs, [:code, :promoter_id, :active, :expires_at, :max_uses, :current_uses])
    |> validate_required([:code, :promoter_id])
    |> validate_number(:current_uses, greater_than_or_equal_to: 0)
    |> validate_max_uses()
    |> validate_usage_limit()
    |> unique_constraint(:code)
  end

  defp validate_max_uses(changeset) do
    case get_field(changeset, :max_uses) do
      nil -> changeset
      max_uses when is_integer(max_uses) and max_uses > 0 -> changeset
      _ -> add_error(changeset, :max_uses, "must be nil or a positive integer")
    end
  end

  defp validate_usage_limit(changeset) do
    max_uses = get_field(changeset, :max_uses)
    current_uses = get_field(changeset, :current_uses)

    if max_uses && current_uses && current_uses > max_uses do
      add_error(changeset, :current_uses, "cannot exceed max_uses")
    else
      changeset
    end
  end
end
