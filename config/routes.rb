Tiler::Engine.routes.draw do
  root to: "dashboards#index"

  resources :dashboards, param: :id do
    member { patch :layout }
    resources :panels, only: [ :new, :create, :edit, :update, :destroy ] do
      member { get :preview }
    end
  end

  resources :data_sources, only: [ :index, :show, :new, :create, :edit, :update, :destroy ], param: :id

  get "/settings", to: "settings#show", as: :settings
  resources :user_widgets, path: "settings/user_widgets",
                          only: [ :index, :new, :create, :edit, :update, :destroy ],
                          param: :id do
    collection do
      post :preview
    end
  end

  post "/ingest/:source_slug", to: "ingest#create", as: :ingest

  namespace :api do
    namespace :v1 do
      resources :dashboards, param: :id, only: [ :index, :show, :create, :update, :destroy ] do
        member { patch :settings }
      end
    end
  end
end
