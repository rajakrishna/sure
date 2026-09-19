# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 Financial Health", type: :request do
  let(:family) { Family.create!(name: "API Family") }
  let(:user) do
    family.users.create!(
      email: "health-api@example.com",
      password: "password123",
      ai_enabled: true,
      preferences: { "preview_features_enabled" => true }
    )
  end
  let(:api_key) do
    key = ApiKey.generate_secure_key
    ApiKey.create!(user: user, name: "API Docs Key", key: key, scopes: %w[read_write], source: "web")
  end
  let(:"X-Api-Key") { api_key.plain_key }

  path "/api/v1/financial_health" do
    get "Show financial health score" do
      tags "Financial Health"
      security [ { apiKeyAuth: [] } ]
      produces "application/json"

      response "200", "health score" do
        schema "$ref" => "#/components/schemas/FinancialHealth"
        run_test!
      end
    end
  end
end
