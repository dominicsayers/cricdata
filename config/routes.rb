Cricdata::Application.routes.draw do
  resources :searches

  resources :players do
    get :xfactor, :xfactorodi, :on => :collection
  end
end
