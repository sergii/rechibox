Rails.application.routes.draw do
  namespace :api do
    post "advice/dry_run", to: "advice#dry_run"
  end
end
