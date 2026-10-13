# frozen_string_literal: true

class ApplicationController < ActionController::API
  before_action :authenticate_user

  private

  def current_user
    request.env.fetch("warden").user
  end

  def authenticate_user
    request.env.fetch("warden").authenticate!
  end
end
