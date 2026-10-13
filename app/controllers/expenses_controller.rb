# frozen_string_literal: true

class ExpensesController < ApplicationController
  def index
    expenses = Expenses::ReviewQueue.new(user: current_user, **index_params.to_h.symbolize_keys).call
    render json: expenses.map { |expense| ExpenseSerializer.new(expense).call }
  rescue Expenses::ReviewQueue::InvalidStatus
    render json: { error: "Invalid status filter" }, status: :bad_request
  rescue Expenses::ReviewQueue::InvalidLimit
    render json: { error: "Limit must be an integer between 1 and #{Expenses::ReviewQueue::MAX_LIMIT}" }, status: :bad_request
  end

  def create
    expense = Expenses::Submit.new(user: current_user, **create_params.to_h.symbolize_keys).call
    render json: ExpenseSerializer.new(expense).call, status: :created
  rescue Expenses::Submit::InvalidAmount => error
    render json: { errors: [ error.message ] }, status: :unprocessable_content
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_content
  end

  def review
    expense = ExpensePolicy.scope(current_user).find(params[:id])
    Expenses::Review.new(expense: expense, reviewer: current_user, **review_params.to_h.symbolize_keys).call
    render json: ExpenseSerializer.new(expense).call
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Expense not found" }, status: :not_found
  rescue Expenses::Review::Forbidden
    render json: { error: "You cannot review this expense" }, status: :forbidden
  rescue Expenses::Review::AlreadyReviewed
    render json: { error: "Expense has already been reviewed" }, status: :conflict
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.full_messages }, status: :unprocessable_content
  end

  private

  def index_params
    params.permit(:status, :limit)
  end

  def create_params
    params.expect(expense: [ :description, :amount, :currency ])
  end

  def review_params
    params.expect(review: [ :outcome, :reason ])
  end
end
