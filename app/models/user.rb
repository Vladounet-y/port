# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password
  has_many :expenses, dependent: :restrict_with_exception
  has_many :expense_decisions, foreign_key: :reviewer_id, dependent: :restrict_with_exception

  enum :role, { employee: "employee", manager: "manager" }, validate: true
  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 12 }, allow_nil: true
end
