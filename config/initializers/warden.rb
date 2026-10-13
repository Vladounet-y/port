# frozen_string_literal: true

require "rack/auth/basic"

Warden::Strategies.add(:http_basic) do
  def valid?
    basic_auth.provided? && basic_auth.params.present? && basic_auth.basic?
  end

  def authenticate!
    email, password = basic_auth.credentials
    user = User.find_by(email: email.strip.downcase)&.authenticate(password)
    user ? success!(user) : fail!("Invalid credentials")
  end

  # Every API request supplies credentials; no session middleware is needed.
  def store?
    false
  end

  private

  def basic_auth
    @basic_auth ||= Rack::Auth::Basic::Request.new(env)
  end
end

Rails.application.config.middleware.use Warden::Manager do |manager|
  manager.default_strategies :http_basic
  manager.failure_app = ->(_env) do
    [
      401,
      { "content-type" => "application/json", "www-authenticate" => 'Basic realm="Expense Review"' },
      [ { error: "Authentication required" }.to_json ]
    ]
  end
end
