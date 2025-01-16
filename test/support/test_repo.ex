defmodule ReferralToolkit.TestRepo do
  @moduledoc false
  use Ecto.Repo,
    otp_app: :referral_toolkit,
    adapter: Ecto.Adapters.Postgres
end
