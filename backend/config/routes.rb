Rails.application.routes.draw do
  namespace :api do
    post "advice", to: "advice#create"
    post "advice/dry_run", to: "advice#dry_run"

    resources :worlds, only: %i[create show] do
      post "resolve_entities", to: "worlds#resolve_entities", on: :member
      get "clarifications", to: "worlds#clarifications", on: :member
      get "clarifications/:clarification_id", to: "worlds#clarification", on: :member
      post "clarifications/:clarification_id/answer", to: "worlds#answer_clarification", on: :member
      get "identity_reviews", to: "worlds#identity_reviews", on: :member
      post "identity_reviews", to: "worlds#review_identity", on: :member
      post "updates", to: "worlds#update_state", on: :member
      post "proposals", to: "worlds#propose_updates", on: :member
      get "proposals", to: "worlds#proposals", on: :member
      get "proposals/:proposal_id", to: "worlds#proposal", on: :member
      post "proposals/:proposal_id/accept", to: "worlds#accept_proposal", on: :member
      post "proposals/:proposal_id/reject", to: "worlds#reject_proposal", on: :member
    end

    resources :conversations, only: %i[create show] do
      post "messages", to: "conversations#reply", on: :member
    end
  end
end
