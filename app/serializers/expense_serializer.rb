# frozen_string_literal: true

class ExpenseSerializer
  def initialize(expense)
    @expense = expense
  end

  def call
    decision = @expense.decision

    {
      id: @expense.id,
      description: @expense.description,
      amount_cents: @expense.amount_cents,
      currency: @expense.currency,
      status: @expense.status,
      created_at: @expense.created_at,
      submitted_by: {
        id: @expense.user.id,
        name: @expense.user.name
      },
      decision: decision && {
        outcome: decision.outcome,
        reason: decision.reason,
        created_at: decision.created_at,
        reviewer: {
          id: decision.reviewer.id,
          name: decision.reviewer.name
        }
      }
    }
  end
end
