Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :biz_txn_types, defaults: { :format => 'json' }

      resources :biz_txn_events, defaults: { :format => 'json' } do
      	resources :biz_txn_party_roles, defaults: { :format => 'json' }

        member do
          put :update_status
        end
      end

      resources :biz_txn_party_roles, defaults: { :format => 'json' }

      resources :biz_txn_acct_roots, defaults: { :format => 'json' }

      resources :biz_txn_acct_types, defaults: { :format => 'json' }

      resources :financial_txns, defaults: { :format => 'json' }
    end
  end

end

ErpTxnsAndAccts::Engine.routes.draw do
end
