Rails.application.routes.draw do
  #handle login / logout
  match "/session/sign_in" => 'erp_tech_svcs/session#create'
  match "/session/sign_out" => 'erp_tech_svcs/session#destroy'
  post "/session/keep_alive" => 'erp_tech_svcs/session#keep_alive'
  get "/session/is_alive" => 'erp_tech_svcs/session#is_alive'

  #handle activation
  get "/users/activate/:activation_token" => 'erp_tech_svcs/user#activate'
  post "/users/reset_password" => 'erp_tech_svcs/user#reset_password'
  post "/users/update_password" => 'erp_tech_svcs/user#update_password'

  namespace :api do
    namespace :v1 do

      post "generate_auth_token" => 'base#generate_auth_token', defaults: { :format => 'json' }
      delete "revoke_auth_token" => 'base#revoke_auth_token', defaults: { :format => 'json' }
      get "auth_token_valid" => 'base#auth_token_valid', defaults: { :format => 'json' }
      get "nmta_groups" => 'groups#nmta_groups',  defaults: { :format => 'json' }
      get "nmta_prospect_groups" => 'groups#nmta_prospect_groups',  defaults: { :format => 'json' }


      resources :parties, defaults: { :format => 'json' } do
        member do
          get :user
        end

        resources :users, defaults: { :format => 'json'}, only: [:create]
      end

      resources :users, defaults: { :format => 'json' } do
        collection do
          get :check_username
        end

        member do
          put :reset_password
          get :effective_security
          put :update_security
          post :update_profile_image
        end

        resources :security_roles, defaults: { :format => 'json' }
        resources :groups, defaults: { :format => 'json' }
        resources :capabilities, defaults: { :format => 'json' }
      end

      resources :audit_logs, defaults: { :format => 'json' } do
        resources :audit_log_items, defaults: { :format => 'json'}
      end

      resources :security_roles, defaults: { :format => 'json' } do
        collection do
          get :selected
          get :available
          put :add
          put :remove
        end
      end

      resources :groups, defaults: { :format => 'json' } do
        member do
          get :effective_security
        end

        collection do
          get :selected
          get :available
          put :add
          put :remove
        end
      end

      resources :capabilities, defaults: { :format => 'json' } do
        collection do
          get :selected
          get :available
          put :add
          put :remove
        end
      end

      resources :file_assets, defaults: { :format => 'json' }

    end
  end

end
