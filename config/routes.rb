Tiler::Engine.routes.draw do
  root to: "dashboards#index"

  resources :dashboards, param: :id do
    resources :panels, only: [ :new, :create, :edit, :update, :destroy ] do
      member { get :preview }
    end
  end

  resources :data_sources, only: [ :index, :show, :new, :create, :edit, :update, :destroy ], param: :id

  post "/ingest/:source_slug", to: "ingest#create", as: :ingest
end
