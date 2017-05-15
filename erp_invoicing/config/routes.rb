Rails.application.routes.draw do

  namespace :api do
    namespace :v1 do

      resources :invoices, :defaults => {:format => 'json'} do
        collection do
          post :generate_invoice
          post :generate_invoices
          get :print_invoices, defaults: { format: 'html' }
          get :generate_pdfs
          get :next_invoice_number
          get :customer_credit_cards
        end

        member do
          get :print_invoice, :defaults => {:format => 'html'}
          get :generate_pdf
          post :make_payment
          put :email_invoice
        end
      end

      resources :payment_applications, defaults: {:format => 'json'} do
        member do
          put :refund
          put :capture
        end
      end

    end # v1
  end # api

end

ErpInvoicing::Engine.routes.draw do
end
