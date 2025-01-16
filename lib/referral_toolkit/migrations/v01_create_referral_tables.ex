defmodule ReferralToolkit.Migrations.V01 do
  @moduledoc false
  use Ecto.Migration

  alias ReferralToolkit.Config

  def up(_) do
    execute("CREATE EXTENSION IF NOT EXISTS citext")

    create table(:referral_toolkit_codes, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:code, :citext, null: false)
      add(:promoter_id, Config.promoter_id_migration_type(), null: false)
      add(:active, :boolean, default: true)
      add(:max_uses, :integer)
      add(:current_uses, :integer, null: false, default: 0)
      add(:expires_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    create table(:referral_toolkit_referrals, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:referral_code_id, references(:referral_toolkit_codes, type: :binary_id), null: false)
      add(:applicant_id, Config.applicant_id_migration_type(), null: false)
      add(:status, :string, null: false)
      add(:completed_at, :utc_datetime_usec)

      timestamps(type: :utc_datetime_usec)
    end

    # Indexes
    create(unique_index(:referral_toolkit_codes, [:code]))
    create(index(:referral_toolkit_codes, [:promoter_id]))
    create(index(:referral_toolkit_referrals, [:referral_code_id]))
    create(index(:referral_toolkit_referrals, [:applicant_id]))
  end

  def down(_) do
    # Drop indexes
    drop(index(:referral_toolkit_referrals, [:applicant_id]))
    drop(index(:referral_toolkit_referrals, [:referral_code_id]))
    drop(index(:referral_toolkit_codes, [:promoter_id]))
    drop(index(:referral_toolkit_codes, [:code]))

    # Drop tables
    drop(table(:referral_toolkit_referrals))
    drop(table(:referral_toolkit_codes))

    # Check if citext is being used by other tables before dropping
    sql = """
    SELECT count(*)
    FROM pg_attribute a
    JOIN pg_class t ON a.attrelid = t.oid
    JOIN pg_namespace n ON t.relnamespace = n.oid
    WHERE a.atttypid = 'citext'::regtype::oid
    AND n.nspname = 'public'
    AND t.relname NOT IN ('referral_toolkit_codes');
    """

    %{rows: [[count]]} = repo().query!(sql)

    if count == 0 do
      execute("DROP EXTENSION IF EXISTS citext")
    end
  end
end
