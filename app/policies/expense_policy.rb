# frozen_string_literal: true

class ExpensePolicy
  def initialize(user, expense)
    @user = user
    @expense = expense
  end

  def review?
    @user.manager? && @expense.user_id != @user.id
  end

  def self.scope(user)
    user.manager? ? Expense.all : user.expenses
  end
end
