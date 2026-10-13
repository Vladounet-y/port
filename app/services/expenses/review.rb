# frozen_string_literal: true

module Expenses
  class Review
    class Forbidden < StandardError; end
    class AlreadyReviewed < StandardError; end

    def initialize(expense:, reviewer:, outcome: nil, reason: nil)
      @expense = expense
      @reviewer = reviewer
      @outcome = outcome
      @reason = reason.to_s.strip.presence
    end

    def call
      raise Forbidden unless ExpensePolicy.new(@reviewer, @expense).review?
      raise AlreadyReviewed unless @expense.pending?

      decision = ExpenseDecision.new(expense: @expense, reviewer: @reviewer, outcome: @outcome, reason: @reason)

      Expense.transaction do
        @expense.update!(status: @outcome)
        decision.save!
      end

      decision
    rescue ActiveRecord::StaleObjectError
      raise AlreadyReviewed, "Expense has already been reviewed"
    end
  end
end
