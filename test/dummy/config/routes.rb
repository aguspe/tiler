Rails.application.routes.draw do
  mount Tiler::Engine => "/tiler"
  root to: redirect("/tiler")
end
