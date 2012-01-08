Cricdata::Application.routes.draw do
  root :to => 'static#api'

  scope ':match_type_name' do
    resources :players, :only => [:xfactor] do
      get 'xfactor', :on => :collection
    end

    resources :scores, :only => [:individual, :team] do
      get 'individual', 'team', :on => :collection
    end
  end

  resources :players

  match ':action' => 'static#:action'
end
