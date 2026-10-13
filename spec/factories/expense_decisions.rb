# frozen_string_literal: true

FactoryBot.define do
  factory :expense_decision do
    association :expense, status: "approved"
    association :reviewer, factory: [ :user, :manager ]
    outcome { "approved" }
    reason { nil }

    transient do
      sync_expense_status { true }
    end

    after(:create) do |decision, evaluator|
      if evaluator.sync_expense_status && decision.expense.status != decision.outcome
        decision.expense.update!(status: decision.outcome)
      end
    end

    trait :rejected do
      outcome { "rejected" }
      reason { "Receipt missing" }
    end

    # Allows a deliberately inconsistent fixture to exercise audit-write rollback.
    trait :without_status_sync do
      sync_expense_status { false }
    end
  end
end
