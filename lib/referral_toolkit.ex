defmodule ReferralToolkit do
  @moduledoc """
  A toolkit for managing referral programs in Phoenix applications.
  """

  import Ecto.Query

  alias ReferralToolkit.Repo
  alias ReferralToolkit.Schemas.Referral
  alias ReferralToolkit.Schemas.ReferralCode

  @doc """
  Creates a new referral code for a promoter.

  ## Options
    * `:max_uses` - maximum number of times the code can be used (default: nil for unlimited)
  """
  @spec create_code(term(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def create_code(promoter_id, opts \\ []) do
    code = generate_unique_code()

    %ReferralCode{}
    |> ReferralCode.changeset(%{
      code: code,
      promoter_id: promoter_id,
      active: true,
      max_uses: Keyword.get(opts, :max_uses),
      current_uses: 0,
      expires_at: DateTime.add(DateTime.utc_now(), 30, :day)
    })
    |> Repo.get_repo().insert([])
    |> case do
      {:ok, referral_code} ->
        {:ok, referral_code.code}

      {:error, changeset} ->
        {:error, "Failed to create referral code: #{inspect(changeset.errors)}"}
    end
  end

  @doc """
  Processes a referral when a new applicant signs up using a referral code.
  The referral starts in a pending state.

  ## Examples
      iex> ReferralToolkit.process_referral("ABC123XYZ", "456")
      {:ok, :referral_pending}
  """
  @spec process_referral(String.t(), term()) :: {:ok, atom()} | {:error, String.t()}
  def process_referral(referral_code, applicant_id) when is_binary(referral_code) do
    with {:ok, code} <- get_valid_code(referral_code),
         {:ok, _referral} <- create_pending_referral(code, applicant_id),
         {:ok, _} <- increment_code_usage(code) do
      {:ok, :referral_pending}
    end
  end

  @doc """
  Processes a referral and marks it as completed in one step.

  ## Examples
      iex> ReferralToolkit.process_and_complete_referral("ABC123XYZ", "456")
      {:ok, :referral_completed}
  """
  @spec process_and_complete_referral(String.t(), term()) :: {:ok, atom()} | {:error, String.t()}
  def process_and_complete_referral(referral_code, applicant_id) when is_binary(referral_code) do
    Repo.get_repo().transaction(fn ->
      with {:ok, code} <- get_valid_code(referral_code),
           {:ok, _referral} <- create_completed_referral(code, applicant_id),
           {:ok, _} <- increment_code_usage(code) do
        {:ok, :referral_completed}
      else
        {:error, reason} -> Repo.get_repo().rollback(reason)
      end
    end)
  end

  @doc """
  Validates if a referral code exists and is still valid.

  ## Examples
      iex> ReferralToolkit.validate_code("ABC123XYZ")
      {:ok, :valid}
  """
  @spec validate_code(String.t()) :: {:ok, atom()} | {:error, String.t()}
  def validate_code(referral_code) when is_binary(referral_code) do
    case get_valid_code(referral_code) do
      {:ok, _code} -> {:ok, :valid}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Gets all referrals made by a specific promoter.

  ## Examples
      iex> ReferralToolkit.get_promoter_referrals("123")
      {:ok, [%{applicant_id: "456", status: :completed}]}
  """
  @spec get_promoter_referrals(term()) :: {:ok, list(map())} | {:error, String.t()}
  def get_promoter_referrals(promoter_id) do
    query =
      from(rc in ReferralCode,
        where: rc.promoter_id == ^promoter_id,
        join: r in assoc(rc, :referrals),
        select: %{
          applicant_id: r.applicant_id,
          status: r.status,
          completed_at: r.completed_at
        }
      )

    {:ok, Repo.get_repo().all(query, query_opts())}
  end

  @doc """
  Updates the status of a referral.
  """
  def update_referral_status(referral_id, new_status) do
    case Repo.get_repo().get(Referral, referral_id, query_opts()) do
      nil ->
        {:error, "Referral not found"}

      referral ->
        attrs = %{
          status: new_status,
          completed_at: if(new_status == :completed, do: DateTime.utc_now())
        }

        referral
        |> Referral.changeset(attrs)
        |> Repo.get_repo().update()
    end
  end

  @doc """
  Gets the active referral code for a promoter if one exists.
  """
  @spec get_promoter_code(term()) :: {:ok, String.t()} | {:error, :no_code}
  def get_promoter_code(promoter_id) do
    query =
      from(rc in ReferralCode,
        where: rc.promoter_id == ^promoter_id,
        where: rc.active == true,
        where: rc.expires_at > ^DateTime.utc_now(),
        limit: 1
      )

    case Repo.get_repo().one(query, query_opts()) do
      nil -> {:error, :no_code}
      code -> {:ok, code.code}
    end
  end

  # Private Functions

  defp get_valid_code(code) do
    query =
      from(rc in ReferralCode,
        where: rc.code == ^code,
        where: rc.active == true,
        where: rc.expires_at > ^DateTime.utc_now(),
        where: is_nil(rc.max_uses) or rc.current_uses < rc.max_uses
      )

    case Repo.get_repo().one(query, query_opts()) do
      nil -> {:error, "Invalid or expired referral code"}
      code -> {:ok, code}
    end
  end

  defp increment_code_usage(code) do
    code
    |> ReferralCode.changeset(%{current_uses: code.current_uses + 1})
    |> Repo.get_repo().update()
  end

  defp create_pending_referral(referral_code, applicant_id) do
    %Referral{}
    |> Referral.changeset(%{
      referral_code_id: referral_code.id,
      applicant_id: applicant_id,
      status: :pending,
      completed_at: nil
    })
    |> Repo.get_repo().insert()
  end

  defp create_completed_referral(referral_code, applicant_id) do
    %Referral{}
    |> Referral.changeset(%{
      referral_code_id: referral_code.id,
      applicant_id: applicant_id,
      status: :completed,
      completed_at: DateTime.utc_now()
    })
    |> Repo.get_repo().insert()
  end

  defp generate_unique_code do
    code = random_code()

    if code_exists?(code) do
      generate_unique_code()
    else
      code
    end
  end

  defp random_code do
    prefix = random_string(3)
    number = 999_999 |> :rand.uniform() |> Integer.to_string() |> String.pad_leading(6, "0")
    "#{prefix}#{number}"
  end

  defp random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode32(padding: false)
    |> binary_part(0, length)
  end

  defp code_exists?(code) do
    query = from(rc in ReferralCode, where: rc.code == ^code)
    Repo.get_repo().exists?(query, query_opts())
  end

  defp query_opts do
    Application.get_env(:referral_toolkit, :query_opts, [])
  end
end
