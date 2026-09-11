Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  resources :experiments, only: %i[index show] do
    get :transitions, on: :member, defaults: { format: :csv }
  end
  resources :findings, only: %i[index show]
  resources :runs, only: :show do
    get :samples, on: :member, defaults: { format: :csv }
  end
  resources :snapshots, only: [] do
    get :png, on: :member
  end

  get "how-it-works" => "pages#how_it_works", as: :how_it_works

  get "lab" => "lab#show", as: :lab
  get "lab/status" => "lab#status", as: :lab_status

  namespace :api do
    resources :runs, only: [] do
      post :claim, on: :collection
      member do
        post :heartbeat
        post :samples
        post :snapshots
        post :finish
        get "snapshots/latest", action: :latest_snapshot, as: :latest_snapshot
        get :world
      end
    end
  end

  root "home#show"
end
