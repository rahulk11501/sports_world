Rails.application.routes.draw do
  namespace :api, defaults: { format: 'json' } do
    namespace :v1 do
      resources :user do
        collection do
          get :insta_images
          post :contact
        end
      end
      resources :auth, only: [], path: '/' do
        collection do
          get     :app_version        # now using http://cf-assets.letsdogether.com/app_version.json
          get     :verify_username
          get     :sign_in
          post    :sign_up
          delete  :logout
          post    :password_sign_in
        end
      end
    end
  end
end
