Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"

  

  namespace "api", defaults: { format: :json } do
    namespace "v1" do
      resources :tasks, except: :show do
        post "complete", on: :member
        post "shuffle", on: :collection
      end
    end
  end
end
