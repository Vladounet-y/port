# frozen_string_literal: true

class Expense < ApplicationRecord
  CURRENCIES = %w[USD EUR UAH].freeze
  MAX_AMOUNT_CENTS = 100_000_000

  belongs_to :user
  has_one :decision, class_name: "ExpenseDecision", dependent: :restrict_with_exception

  enum :status, { pending: "pending", approved: "approved", rejected: "rejected" }, validate: true

  validates :description, presence: true, length: { maximum: 500 }
  validates :amount_cents, numericality: {
    only_integer: true, greater_than: 0, less_than_or_equal_to: MAX_AMOUNT_CENTS
  }
  validates :currency, inclusion: { in: CURRENCIES }
end
