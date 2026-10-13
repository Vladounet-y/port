# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Expenses API", type: :request do
  include_context "expense users"

  let(:expense) { create(:expense, user: employee) }
  let(:employee_headers) do
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(employee.email, employee.password) }
  end
  let(:manager_headers) do
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(manager.email, manager.password) }
  end
  let(:incorrect_password_headers) do
    { "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials(employee.email, "wrong") }
  end
  let(:invalid_authorization_headers) do
    [ "Basic", "Basic !!!", "Bearer token", "Basic #{Base64.strict_encode64('missing-password')}" ]
  end
  let(:invalid_limits) { [ "0", "-1", "101", "1.5", "invalid" ] }
  let(:malformed_expense_payloads) { [ {}, { expense: "invalid" }, { expense: [ "invalid" ] } ] }
  let(:malformed_review_payloads) { [ {}, { review: "invalid" }, { review: [ "invalid" ] } ] }

  it "requires credentials and rejects incorrect passwords" do
    get expenses_path
    expect(response).to have_http_status(:unauthorized)
    expect(response.parsed_body["error"]).to eq("Authentication required")
    expect(response.headers["WWW-Authenticate"]).to eq('Basic realm="Expense Review"')

    get expenses_path, headers: incorrect_password_headers
    expect(response).to have_http_status(:unauthorized)
  end

  it "authenticates each request through Warden without creating a session" do
    get expenses_path, headers: employee_headers
    expect(response).to have_http_status(:ok)
    expect(response.headers["Set-Cookie"]).to be_nil

    get expenses_path
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects malformed and unsupported authorization headers" do
    invalid_authorization_headers.each do |header|
      get expenses_path, headers: { "Authorization" => header }
      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body["error"]).to eq("Authentication required")
    end
  end

  it "submits for the authenticated employee and ignores unpermitted attributes" do
    create(:expense, user: manager)

    post expenses_path, params: {
      expense: { description: "Train ticket", amount: "42.50", currency: "EUR", user_id: manager.id, status: "approved" }
    }, headers: employee_headers, as: :json
    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("submitted_by", "id")).to eq(employee.id)
    expect(response.parsed_body["amount_cents"]).to eq(4250)
    expect(response.parsed_body["status"]).to eq("pending")
    expect(response.parsed_body.to_s).not_to include("password_digest")

    get expenses_path, headers: employee_headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.length).to eq(1)
  end

  it "approves as the authenticated manager and ignores injected reviewer attributes" do
    post review_expense_path(expense), params: {
      review: { outcome: "approved", reviewer_id: employee.id, expense_id: 999, status: "rejected" }
    }, headers: manager_headers, as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["status"]).to eq("approved")
    expect(response.parsed_body.dig("decision", "reviewer", "id")).to eq(manager.id)
    expect(expense.reload.decision.expense_id).to eq(expense.id)
  end

  context "when an employee tries to review another user's expense" do
    let(:expense) { create(:expense, user: manager) }

    it "returns not found" do
      post review_expense_path(expense), params: { review: { outcome: "approved" } }, headers: employee_headers, as: :json
      expect(response).to have_http_status(:not_found)
      expect(expense.reload).to be_pending
    end
  end

  it "forbids employees from reviewing their own expenses" do
    post review_expense_path(expense), params: { review: { outcome: "approved" } }, headers: employee_headers, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(expense.reload).to be_pending
  end

  context "when the manager owns the expense" do
    let(:expense) { create(:expense, user: manager) }

    it "forbids self approval" do
      post review_expense_path(expense), params: { review: { outcome: "approved" } }, headers: manager_headers, as: :json
      expect(response).to have_http_status(:forbidden)
      expect(expense.reload).to be_pending
    end
  end

  it "rejects a rejection with no reason and leaves the expense pending" do
    post review_expense_path(expense), params: { review: { outcome: "rejected", reason: " " } }, headers: manager_headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(expense.reload).to be_pending
  end

  context "when the expense has already been approved" do
    let(:expense) { create(:expense, :approved, user: employee) }

    it "returns conflict without creating another decision" do
      expense
      expect {
        post review_expense_path(expense), params: { review: { outcome: "approved" } }, headers: manager_headers, as: :json
      }.not_to change(ExpenseDecision, :count)
      expect(response).to have_http_status(:conflict)
    end
  end

  it "returns a validation error for a missing review outcome" do
    post review_expense_path(expense), params: { review: { reason: "Missing outcome" } }, headers: manager_headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns bad request for an invalid filter and validation errors for invalid money" do
    get expenses_path(status: "unknown"), headers: manager_headers
    expect(response).to have_http_status(:bad_request)
    post expenses_path, params: { expense: { description: "Train", amount: "1.234", currency: "EUR" } }, headers: employee_headers, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "accepts a frontend queue limit" do
    create_list(:expense, 3, user: employee)

    get expenses_path(limit: 2), headers: manager_headers
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.length).to eq(2)
    expect(response.parsed_body.first.dig("submitted_by", "id")).to eq(employee.id)
    expect(response.parsed_body.first["amount_cents"]).to eq(4250)
  end

  it "returns bad request for invalid frontend limits" do
    invalid_limits.each do |limit|
      get expenses_path(limit: limit), headers: manager_headers
      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["error"]).to eq("Limit must be an integer between 1 and 100")
    end
  end

  it "requires a nested expense object instead of accepting malformed input" do
    malformed_expense_payloads.each do |payload|
      post expenses_path, params: payload, headers: employee_headers, as: :json
      expect(response).to have_http_status(:bad_request)
    end
  end

  it "requires a nested review object instead of accepting malformed input" do
    malformed_review_payloads.each do |payload|
      post review_expense_path(expense), params: payload, headers: manager_headers, as: :json
      expect(response).to have_http_status(:bad_request)
      expect(expense.reload).to be_pending
    end
  end
end
