# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
abort "Specs cannot run in production!" if Rails.env.production?
require "rspec/rails"

ActiveRecord::Migration.maintain_test_schema!
ActiveModel::SecurePassword.min_cost = true

RSpec.shared_context "expense users" do
  let(:employee) { create(:user) }
  let(:manager) { create(:user, :manager) }
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.include FactoryBot::Syntax::Methods
  config.expect_with(:rspec) { |expectations| expectations.syntax = :expect }
  config.mock_with(:rspec) { |mocks| mocks.verify_partial_doubles = true }
  config.order = :random
  Kernel.srand config.seed
end
