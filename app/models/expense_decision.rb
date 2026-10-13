# frozen_string_literal: true

class ExpenseDecision < ApplicationRecord
  belongs_to :expense
  belongs_to :reviewer, class_name: "User"

  enum :outcome, { approved: "approved", rejected: "rejected" }, validate: true
  validates :reason, presence: true, if: :rejected?
  validates :reason, length: { maximum: 500 }

  def readonly?
    persisted? || super
  end
end
