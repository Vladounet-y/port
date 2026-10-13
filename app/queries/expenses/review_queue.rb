# frozen_string_literal: true

module Expenses
  class ReviewQueue
    DEFAULT_LIMIT = 50
    MAX_LIMIT = 100

    class InvalidStatus < StandardError; end
    class InvalidLimit < StandardError; end

    def initialize(user:, status: "pending", limit: DEFAULT_LIMIT)
      @user = user
      @status = status
      @limit = Integer(limit.to_s, 10, exception: false)
    end

    def call
      raise InvalidStatus unless Expense.statuses.key?(@status)
      raise InvalidLimit unless @limit&.between?(1, MAX_LIMIT)

      ExpensePolicy.scope(@user)
        .where(status: @status)
        .includes(:user, decision: :reviewer)
        .order(created_at: :desc, id: :desc)
        .limit(@limit)
    end
  end
end
