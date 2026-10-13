# frozen_string_literal: true

class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :amount_cents, null: false
      t.string :currency, null: false
      t.string :status, null: false, default: "pending"
      t.integer :lock_version, null: false, default: 0
      t.timestamps
    end
    add_index :expenses, [ :status, :created_at ]
  end
end
