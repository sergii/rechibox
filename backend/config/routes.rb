Rails.application.routes.draw do
  namespace :api do
    post "advice", to: "advice#create"
    post "advice/dry_run", to: "advice#dry_run"

    resources :conversations, only: %i[create show] do
      post :messages, action: :reply, on: :member
    end
  end
end
