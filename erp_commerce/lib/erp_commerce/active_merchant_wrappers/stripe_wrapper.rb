require 'active_merchant'

module ErpCommerce
  module ActiveMerchantWrappers
    class StripeWrapper

      def self.purchase(credit_card, amount, cvv, gateway_options={})
        result = {}

        gateway = ActiveMerchant::Billing::StripeGateway.new(:login => gateway_options[:private_key])

        ActiveMerchant::Billing::Base.mode = :test

        #set credit card info
        credit_card_result = ActiveMerchant::Billing::CreditCard.new({
                                                                         :first_name         => credit_card.first_name_on_card,
                                                                         :last_name          => credit_card.last_name_on_card,
                                                                         :number             => credit_card.private_card_number,
                                                                         :month              => credit_card.expiration_month,
                                                                         :year               => credit_card.expiration_year,
                                                                         :verification_value => cvv,
                                                                         :type               => ErpCommerce::ActiveMerchantWrappers::CreditCardValidation.get_card_type(credit_card.private_card_number)
                                                                     })

        if credit_card_result.valid?
          cents = (amount.to_d * 100).to_i
          response = gateway.purchase(cents, credit_card_result)

          if response.success?
            result[:message] = response.message
            result[:payment] = Payment.new
            result[:payment].authorization_code = response.authorization
            result[:payment].success = true
            result[:payment].purchase
          else
            result[:message] = response.message
            result[:payment] = Payment.new
            result[:payment].success = false
            result[:payment].decline
          end

          gateway = PaymentGateway.create(
              :response => response.message,
              :payment_gateway_action => PaymentGatewayAction.find_by_internal_identifier('authorize')
          )

          result[:payment].payment_gateways << gateway
          result[:payment].save
        else
          result[:message] = "<ul>"
          credit_card_result.errors.full_messages.each do |current_notice_msg|
            result[:message] << "<li>"
            result[:message] << current_notice_msg
            result[:message] << "</li>"
          end
          result[:message] << "<ul>"
        end

        result
      end

    end#StripeWrapper
  end#ActiveMerchantWrappers
end#ErpCommerce