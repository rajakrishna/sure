# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 AI Proposals", type: :request do
  let(:family) { Family.create!(name: "API Family") }
  let(:user) do
    family.users.create!(
      email: "proposals-api@example.com",
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

  path "/api/v1/ai_proposals" do
    get "List pending AI proposals" do
      tags "AI Proposals"
      security [ { apiKeyAuth: [] } ]
      produces "application/json"

      response "200", "proposals listed" do
        schema "$ref" => "#/components/schemas/AiProposalCollection"
        run_test!
      end
    end
  end
end
