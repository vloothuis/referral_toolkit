defmodule ReferralToolkit.DataCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox

  using _options do
    quote do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ReferralToolkit.DataCase

      setup do
        Application.put_env(:referral_toolkit, :repo, ReferralToolkit.TestRepo)
      end
    end
  end

  setup tags do
    ReferralToolkit.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Sandbox.start_owner!(ReferralToolkit.TestRepo, shared: not tags[:async])
    on_exit(fn -> Sandbox.stop_owner(pid) end)
  end
end
