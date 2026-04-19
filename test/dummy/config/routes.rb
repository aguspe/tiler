Rails.application.routes.draw do
  mount Tiler::Engine => "/tiler"
end
