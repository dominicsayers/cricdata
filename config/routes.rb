Cricdata::Application.routes.draw do
  root :to => 'static#api'

  resources :players

  scope ':match_type_name', :constraints => {:match_type_name => /test|odi|t20i/} do
    resources :players, :only => [:xfactor] do
      get 'xfactor', :on => :collection
    end

    scope '/scores' do
      resources :individual,  :controller => :individual_scores
      resources :team,        :controller => :team_scores
    end
  end

  get ':action' => 'static#:action'
end
