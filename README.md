# Referral Toolkit

A Phoenix-compatible Elixir library for managing referral programs in your web application. This toolkit provides functionality to generate, track, and validate referral codes, making it easy to implement referral systems.

## Features

- Generate unique referral codes for users
- Track referral code usage and conversions
- Link referrals to user accounts
- Support for custom rewards and referral conditions
- Seamless integration with Phoenix applications

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `referral_toolkit` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:referral_toolkit, "~> 0.1.0"}
  ]
end
```

## Usage Example

```elixir
# Generate a referral code for a user
{:ok, referral_code} = ReferralToolkit.create_code(user_id)

# Validate and process a referral
ReferralToolkit.process_referral(referral_code, new_user_id)
```

## Documentation

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/referral_toolkit>.
