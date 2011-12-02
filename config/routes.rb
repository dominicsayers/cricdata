Cricdata::Application.routes.draw do
#-  resources :test, :controller => 'match_types'
#-  resources :odi, :controller => 'match_types'
#-  resources :t20i, :controller => 'match_types'

  scope ':match_type_name' do
    resources :players do
      get 'xfactor', :on => :collection
    end
  end

  resources :match_type_players do
    get 'xfactor', :on => :collection
  end
end
