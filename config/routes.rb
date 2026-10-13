# frozen_string_literal: true

Rails.application.routes.draw do
  resources :expenses, only: %i[index create], defaults: { format: :json } do
    post :review, on: :member
  end
end
