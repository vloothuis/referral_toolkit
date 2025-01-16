import Config

config :referral_toolkit, ReferralToolkit.TestRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "referral_toolkit_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  priv: "test/support",
  log: false

config :referral_toolkit, ecto_repos: [ReferralToolkit.TestRepo]

config :referral_toolkit,
  repo: ReferralToolkit.TestRepo,
  promoter_id_type: :bigint,
  applicant_id_type: :bigint,
  promoter_id_schema_type: :integer,
  applicant_id_schema_type: :integer
