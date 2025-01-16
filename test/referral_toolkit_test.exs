defmodule ReferralToolkitTest do
  use ReferralToolkit.DataCase

  import Mox

  alias ReferralToolkit.Schemas.Referral
  alias ReferralToolkit.Schemas.ReferralCode
  alias ReferralToolkit.TestRepo

  # Setup Mox expectations for the current test process
  setup :verify_on_exit!

  describe "create_code/1" do
    test "creates a valid referral code" do
      {:ok, code} = ReferralToolkit.create_code(123)

      created_code = TestRepo.get_by(ReferralCode, code: code)
      assert created_code.promoter_id == 123
      assert is_binary(code)
      assert String.length(code) == 9
    end
  end

  describe "create_code/2" do
    test "creates a valid referral code with usage limit" do
      {:ok, code} = ReferralToolkit.create_code(123, max_uses: 2)

      created_code = TestRepo.get_by(ReferralCode, code: code)
      assert created_code.promoter_id == 123
      assert created_code.max_uses == 2
      assert created_code.current_uses == 0
    end
  end

  describe "process_referral/2" do
    test "processes valid referral" do
      code = "ABC123XYZ"

      referral_code = %ReferralCode{
        code: code,
        active: true,
        promoter_id: 123,
        expires_at: DateTime.add(DateTime.utc_now(), 1, :day)
      }

      {:ok, _inserted} = TestRepo.insert(referral_code)

      result = ReferralToolkit.process_referral(code, 456)
      assert {:ok, _} = result

      referral = TestRepo.get_by(Referral, applicant_id: 456)
      assert referral.status == :pending
    end

    test "creates pending referral" do
      code = "ABC123XYZ"

      referral_code = %ReferralCode{
        code: code,
        active: true,
        promoter_id: 123,
        current_uses: 0,
        expires_at: DateTime.add(DateTime.utc_now(), 1, :day)
      }

      {:ok, _inserted} = TestRepo.insert(referral_code)

      result = ReferralToolkit.process_referral(code, 456)
      assert {:ok, :referral_pending} = result

      referral = TestRepo.get_by(Referral, applicant_id: 456)
      assert referral.status == :pending
      assert referral.completed_at == nil

      updated_code = TestRepo.get_by(ReferralCode, code: code)
      assert updated_code.current_uses == 1
    end

    test "respects usage limits" do
      {:ok, code} = ReferralToolkit.create_code(123, max_uses: 1)

      # First use succeeds
      assert {:ok, _} = ReferralToolkit.process_referral(code, 456)

      # Second use fails
      assert {:error, "Invalid or expired referral code"} =
               ReferralToolkit.process_referral(code, 789)
    end

    test "returns error for invalid code" do
      result = ReferralToolkit.process_referral("INVALID", 456)
      assert {:error, "Invalid or expired referral code"} = result
    end
  end

  describe "process_and_complete_referral/2" do
    test "processes and completes valid referral" do
      code = "ABC123XYZ"

      referral_code = %ReferralCode{
        code: code,
        active: true,
        promoter_id: 123,
        current_uses: 0,
        expires_at: DateTime.add(DateTime.utc_now(), 1, :day)
      }

      {:ok, _inserted} = TestRepo.insert(referral_code)

      result = ReferralToolkit.process_and_complete_referral(code, 456)
      assert {:ok, {:ok, :referral_completed}} = result

      referral = TestRepo.get_by(Referral, applicant_id: 456)
      assert referral.status == :completed
      assert referral.completed_at != nil

      updated_code = TestRepo.get_by(ReferralCode, code: code)
      assert updated_code.current_uses == 1
    end

    test "returns error for invalid code" do
      result = ReferralToolkit.process_and_complete_referral("INVALID", 456)
      assert {:error, "Invalid or expired referral code"} = result
    end
  end

  describe "validate_code/1" do
    test "validates existing code" do
      code = "ABC123XYZ"

      referral_code = %ReferralCode{
        code: code,
        active: true,
        promoter_id: 123,
        expires_at: DateTime.add(DateTime.utc_now(), 1, :day)
      }

      {:ok, _inserted} = TestRepo.insert(referral_code)

      assert {:ok, :valid} = ReferralToolkit.validate_code(code)
    end

    test "returns error for invalid code" do
      assert {:error, "Invalid or expired referral code"} =
               ReferralToolkit.validate_code("INVALID")
    end
  end

  describe "get_promoter_referrals/1" do
    test "returns list of referrals" do
      # Insert test data
      {:ok, code} = ReferralToolkit.create_code(123)
      referral_code = TestRepo.get_by(ReferralCode, code: code)

      referral = %Referral{
        referral_code_id: referral_code.id,
        applicant_id: 456,
        status: :completed
      }

      {:ok, _inserted} = TestRepo.insert(referral)

      {:ok, referrals} = ReferralToolkit.get_promoter_referrals(123)
      assert length(referrals) == 1
      [first | _] = referrals
      assert first.applicant_id == 456
      assert first.status == :completed
    end
  end

  describe "update_referral_status/2" do
    test "updates referral status to completed" do
      {:ok, code} = ReferralToolkit.create_code(123)
      {:ok, :referral_pending} = ReferralToolkit.process_referral(code, 456)

      referral = TestRepo.get_by(Referral, applicant_id: 456)
      assert referral.status == :pending
      assert referral.completed_at == nil
    end

    test "updates referral from pending to completed" do
      {:ok, code} = ReferralToolkit.create_code(123)
      {:ok, :referral_pending} = ReferralToolkit.process_referral(code, 456)

      referral = TestRepo.get_by(Referral, applicant_id: 456)
      assert referral.status == :pending

      {:ok, updated_referral} = ReferralToolkit.update_referral_status(referral.id, :completed)
      assert updated_referral.status == :completed
      assert updated_referral.completed_at != nil
    end

    for {old, new} <- [
          {:completed, :expired},
          {:expired, :completed}
        ] do
      test "returns error for invalid status transition from #{old} to #{new}" do
        {:ok, code} = ReferralToolkit.create_code(123)
        {:ok, _} = ReferralToolkit.process_referral(code, 456)

        referral = TestRepo.get_by(Referral, applicant_id: 456)
        {:ok, _referral} = ReferralToolkit.update_referral_status(referral.id, unquote(old))
        assert {:error, _} = ReferralToolkit.update_referral_status(referral.id, unquote(new))
      end
    end
  end
end
