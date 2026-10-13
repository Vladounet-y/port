# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExpenseSerializer, type: :model do
  include_context "expense users"

  subject(:json) { JSON.parse(described_class.new(expense).call.to_json) }

  let(:expense) { create(:expense, user: employee) }
  let(:response_fields) { %w[id description amount_cents currency status created_at submitted_by decision] }
  let(:decision_fields) { %w[outcome reason created_at reviewer] }

  it "exposes only public fields with no decision for a pending expense" do
    expect(json.keys).to match_array(response_fields)
    expect(json["submitted_by"]).to eq("id" => employee.id, "name" => employee.name)
    expect(json["decision"]).to be_nil
    expect(json.to_s).not_to include(employee.email, employee.password_digest, "lock_version")
  end

  context "with a rejected expense" do
    let(:expense) { create(:expense, :rejected, user: employee) }
    let(:reviewer) { expense.decision.reviewer }

    it "includes the decision and public reviewer details" do
      expect(json["decision"].keys).to match_array(decision_fields)
      expect(json["decision"]).to include("outcome" => "rejected", "reason" => "Receipt missing")
      expect(json.dig("decision", "reviewer")).to eq("id" => reviewer.id, "name" => reviewer.name)
      expect(json.to_s).not_to include(reviewer.email, reviewer.password_digest)
    end
  end
end
