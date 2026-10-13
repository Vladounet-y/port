# frozen_string_literal: true

module Expenses
  class Submit
    class InvalidAmount < StandardError; end

    def initialize(user:, description: nil, amount: nil, currency: nil)
      @user = user
      @description = description
      @amount = amount
      @currency = currency
    end

    def call
      unless @amount.is_a?(String) && @amount.match?(/\A\d{1,7}(\.\d{1,2})?\z/)
        raise InvalidAmount, "Amount must be a decimal string with up to two decimal places"
      end

      @user.expenses.create!(
        description: @description,
        amount_cents: (BigDecimal(@amount) * 100).to_i,
        currency: @currency
      )
    end
  end
end
