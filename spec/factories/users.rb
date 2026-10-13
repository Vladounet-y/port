# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |number| "employee#{number}@example.com" }
    name { "Employee" }
    role { "employee" }
    password { "test-password-2026" }

    trait :manager do
      name { "Manager" }
      role { "manager" }
    end
  end
end
