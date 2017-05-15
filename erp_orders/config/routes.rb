Rails.application.routes.draw do

  namespace :api do
    namespace :v1 do

      resources :order_txns, defaults: { :format => 'json' } do
        member do
          put :update_status
          get :related_order_txns
          get :parties
        end
        resources :charge_lines
      end

      resources :order_line_items, defaults: { :format => 'json' }
      resources :charge_lines, defaults: { :format => 'json' }

    end
  end

end

ErpOrders::Engine.routes.draw do
end
