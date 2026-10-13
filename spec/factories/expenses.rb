# frozen_string_literal: true

FactoryBot.define do
  factory :expense do
    association :user
    description { "Client meeting travel" }
    amount_cents { 4250 }
    currency { "EUR" }
    status { "pending" }

    trait :approved do
      status { "approved" }
      after(:create) { |expense| create(:expense_decision, expense: expense) }
    end

    trait :rejected do
      status { "rejected" }
      after(:create) { |expense| create(:expense_decision, :rejected, expense: expense) }
    end
  end
end
