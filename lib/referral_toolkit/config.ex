defmodule ReferralToolkit.Config do
  @moduledoc false
  def promoter_id_migration_type do
    Application.get_env(:referral_toolkit, :promoter_id_type, :bigint)
  end

  def applicant_id_migration_type do
    Application.get_env(:referral_toolkit, :applicant_id_type, :bigint)
  end

  def promoter_id_schema_type do
    Application.get_env(:referral_toolkit, :promoter_id_schema_type, :integer)
  end

  def applicant_id_schema_type do
    Application.get_env(:referral_toolkit, :applicant_id_schema_type, :integer)
  end
end
