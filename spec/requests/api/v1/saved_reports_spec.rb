# frozen_string_literal: true

require "swagger_helper"

RSpec.describe "API V1 Saved Reports", type: :request do
  let(:family) { Family.create!(name: "API Family") }
  let(:user) do
    family.users.create!(
      email: "reports-api@example.com",
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

  path "/api/v1/saved_reports" do
    get "List saved reports" do
      tags "Saved Reports"
      security [ { apiKeyAuth: [] } ]
      produces "application/json"

      response "200", "saved reports listed" do
        schema "$ref" => "#/components/schemas/SavedReportCollection"
        run_test!
      end
    end

    post "Create a saved report" do
      tags "Saved Reports"
      security [ { apiKeyAuth: [] } ]
      consumes "application/json"
      produces "application/json"
      parameter name: :saved_report, in: :body, schema: {
        type: :object,
        properties: {
          saved_report: {
            type: :object,
            properties: {
              name: { type: :string },
              config: { type: :object }
            }
          }
        }
      }

      response "201", "saved report created" do
        schema "$ref" => "#/components/schemas/SavedReportResponse"
        let(:saved_report) { { saved_report: { name: "Monthly", config: { period_type: "monthly", sections: [ "net_worth" ] } } } }
        run_test!
      end
    end
  end
end
