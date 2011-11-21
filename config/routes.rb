Cricdata::Application.routes.draw do
  resources :searches

  resources :players do
    get :xfactor, :on => :collection
  end
end
