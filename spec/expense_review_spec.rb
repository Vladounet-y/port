# frozen_string_literal: true

require "rails_helper"

RSpec.describe Expenses::Submit, type: :model do
  include_context "expense users"

  subject(:submit) { described_class.new(user: employee, **submission_attributes).call }

  let(:submission_attributes) { { description: "Workshop", amount: "128.99", currency: "USD" } }
  let(:invalid_amounts) { [ "12.345", "1e3", "-1", "abc", "", "1,000.00", 12.34, nil ] }
  let(:invalid_amount_currency_pairs) { [ [ "0", "USD" ], [ "1000000.01", "USD" ], [ "10", "XYZ" ] ] }
  let(:invalid_amount_submissions) do
    invalid_amounts.map do |amount|
      described_class.new(user: employee, **submission_attributes.merge(amount: amount))
    end
  end
  let(:invalid_currency_or_range_submissions) do
    invalid_amount_currency_pairs.map do |amount, currency|
      described_class.new(user: employee, **submission_attributes.merge(amount: amount, currency: currency))
    end
  end

  it "converts decimal money exactly and starts pending" do
    expect(submit.amount_cents).to eq(12899)
    expect(submit.user).to eq(employee)
    expect(submit).to be_pending
  end

  it "rejects ambiguous or imprecise monetary inputs without creating expenses" do
    invalid_amount_submissions.each do |submission|
      expect {
        expect { submission.call }.to raise_error(described_class::InvalidAmount)
      }.not_to change(Expense, :count)
    end
  end

  it "rejects zero and excessive amounts and unsupported currencies" do
    invalid_currency_or_range_submissions.each do |submission|
      expect { submission.call }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
end

RSpec.describe Expenses::Review, type: :model do
  include_context "expense users"

  subject(:review) { described_class.new(expense: review_expense, reviewer: reviewer, outcome: outcome, reason: reason).call }

  let(:expense) { create(:expense, user: employee) }
  let(:review_expense) { expense }
  let(:reviewer) { manager }
  let(:outcome) { "approved" }
  let(:reason) { nil }

  it "persists an attributable audit record and approval together" do
    expense
    expect { review }.to change(ExpenseDecision, :count).by(1)
    expect(review.reviewer).to eq(manager)
    expect(review.expense).to eq(expense)
    expect(review.outcome).to eq("approved")
    expect(expense.reload).to be_approved
  end

  context "when rejecting an expense" do
    let(:outcome) { "rejected" }
    let(:reason) { "  Receipt is missing  " }

    it "trims and records the rejection reason" do
      expect(review.reason).to eq("Receipt is missing")
      expect(expense.reload).to be_rejected
    end

    context "without a reason" do
      let(:reason) { "  " }

      it "rolls back the state and audit" do
        expense
        expect {
          expect { review }.to raise_error(ActiveRecord::RecordInvalid)
        }.not_to change(ExpenseDecision, :count)
        expect(expense.reload).to be_pending
        expect(expense.lock_version).to eq(0)
      end
    end
  end

  context "with an unsupported outcome" do
    let(:outcome) { "paid" }

    it "cannot alter the expense" do
      expect { review }.to raise_error(ActiveRecord::RecordInvalid)
      expect(expense.reload).to be_pending
      expect(expense.decision).to be_nil
    end
  end

  context "with an employee reviewer" do
    let(:reviewer) { employee }

    it "forbids review at the service boundary" do
      expense
      expect {
        expect { review }.to raise_error(described_class::Forbidden)
      }.not_to change(ExpenseDecision, :count)
      expect(expense.reload).to be_pending
    end
  end

  context "when the manager owns the expense" do
    let(:expense) { create(:expense, user: manager) }

    it "forbids self review at the service boundary" do
      expense
      expect {
        expect { review }.to raise_error(described_class::Forbidden)
      }.not_to change(ExpenseDecision, :count)
      expect(expense.reload).to be_pending
    end
  end

  context "when the expense is already approved" do
    let(:expense) { create(:expense, :approved, user: employee) }
    let(:outcome) { "rejected" }
    let(:reason) { "Late decision" }

    it "returns a conflict without a second audit" do
      expense
      expect {
        expect { review }.to raise_error(described_class::AlreadyReviewed)
      }.not_to change(ExpenseDecision, :count)
    end
  end

  context "when another manager reviews the same snapshot" do
    let(:review_expense) { Expense.find(expense.id) }
    let(:reviewer) { create(:user, :manager) }
    let(:outcome) { "rejected" }
    let(:reason) { "Late decision" }
    let(:winning_review) { described_class.new(expense: expense, reviewer: manager, outcome: "approved") }

    before do
      review_expense
      winning_review.call
    end

    it "cannot overwrite the winning decision" do
      expect {
        expect { review }.to raise_error(described_class::AlreadyReviewed)
      }.not_to change(ExpenseDecision, :count)
      expect(expense.reload).to be_approved
      expect(expense.decision.reviewer).to eq(manager)
    end
  end

  context "when the audit insert violates its unique index" do
    before { create(:expense_decision, :without_status_sync, expense: expense, reviewer: manager) }

    it "rolls back a valid state transition" do
      expect {
        expect { review }.to raise_error(ActiveRecord::RecordNotUnique)
      }.not_to change(ExpenseDecision, :count)
      expect(expense.reload).to be_pending
      expect(expense.lock_version).to eq(0)
    end
  end
end

RSpec.describe ExpenseDecision, type: :model do
  let(:decision) { create(:expense_decision) }

  it "prevents ordinary Active Record writes from changing a persisted decision" do
    expect { decision.update!(reason: "Changed history") }.to raise_error(ActiveRecord::ReadOnlyRecord)
  end
end

RSpec.describe Expenses::ReviewQueue, type: :model do
  include_context "expense users"

  subject(:queue) { described_class.new(user: user, status: status, limit: limit).call }

  let(:user) { manager }
  let(:status) { "pending" }
  let(:limit) { described_class::DEFAULT_LIMIT }
  let(:invalid_limits) { [ 0, -1, 101, "invalid", "1.5", 1.5, "", nil ] }
  let(:invalid_limit_queries) { invalid_limits.map { |value| described_class.new(user: user, limit: value) } }
  let!(:own_expense) { create(:expense, user: employee) }
  let!(:manager_expense) { create(:expense, user: manager) }
  let!(:completed_expense) { create(:expense, :approved, user: employee) }

  it "shows pending expenses to managers" do
    expect(queue.pluck(:id)).to eq([ manager_expense.id, own_expense.id ])
  end

  context "with an employee" do
    let(:user) { employee }

    it "shows only their own expenses" do
      expect(queue.pluck(:id)).to eq([ own_expense.id ])
    end
  end

  context "with an approved status filter" do
    let(:status) { "approved" }

    it "shows only approved expenses" do
      expect(queue.pluck(:id)).to eq([ completed_expense.id ])
    end
  end

  context "with an invalid status filter" do
    let(:status) { "paid" }

    it "rejects the filter" do
      expect { queue }.to raise_error(described_class::InvalidStatus)
    end
  end

  context "with more expenses than the default limit" do
    let(:timestamp) { Time.current }
    let!(:expenses) { create_list(:expense, 51, user: employee, created_at: timestamp) }

    it "applies the default limit and uses id to break timestamp ties" do
      results = queue.to_a
      expect(results.length).to eq(50)
      expect(results.map(&:id)).to eq(expenses.map(&:id).sort.reverse.first(50))
    end

    context "with a frontend limit" do
      let(:limit) { "2" }

      it "returns the requested number of expenses" do
        expect(queue.size).to eq(2)
      end
    end

    context "with the maximum limit" do
      let(:limit) { 100 }

      it "allows more than the default number of results" do
        expect(queue.size).to eq(53)
      end
    end
  end

  it "rejects invalid or unbounded limits" do
    invalid_limit_queries.each do |query|
      expect { query.call }.to raise_error(described_class::InvalidLimit)
    end
  end
end
