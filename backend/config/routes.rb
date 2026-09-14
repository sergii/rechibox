Rails.application.routes.draw do
  namespace :api do
    post "advice", to: "advice#create"
    post "advice/dry_run", to: "advice#dry_run"

    resources :worlds, only: %i[create show]

    resources :conversations, only: %i[create show] do
      post "messages", to: "conversations#reply", on: :member
    end
  end
end
