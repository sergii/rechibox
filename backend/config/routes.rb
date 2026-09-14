Rails.application.routes.draw do
  namespace :api do
    post "advice", to: "advice#create"
    post "advice/dry_run", to: "advice#dry_run"

    resources :worlds, only: %i[create show] do
      get "entities", to: "world_queries#entities", on: :member
      get "claims", to: "world_queries#claims", on: :member
      get "graph", to: "world_queries#graph", on: :member
      post "query", to: "world_queries#query", on: :member
      get "entities/:entity_id/physical_location", to: "world_queries#physical_location", on: :member
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
      get "turns", to: "conversations#turns", on: :member
      get "turns/:turn_id", to: "conversations#turn", on: :member
      post "clarifications/:clarification_id/answer", to: "conversations#resume_clarification", on: :member
    end
  end
end
