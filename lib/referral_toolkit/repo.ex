defmodule ReferralToolkit.Repo do
  def get_repo do
    Application.get_env(:referral_toolkit, :repo) ||
      raise "Referral Toolkit repo not configured. Add repo: YourRepo to the referral_toolkit config"
  end
end
