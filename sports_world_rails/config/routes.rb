Rails.application.routes.draw do
  namespace :api, defaults: { format: 'json' } do
    namespace :v1 do
      resources :user do
        collection do
          get :insta_images
          post :contact
        end
      end
    end
  end
end
