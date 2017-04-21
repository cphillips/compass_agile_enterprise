module API
  module V1
    class PaymentApplicationsController < BaseController

=begin

  @api {get} /api/v1/payment_applications/:id/refund
  @apiVersion 1.0.0
  @apiName RefundPaymentApplication
  @apiGroup PaymentApplication

  @apiSuccess {Boolean} success True if the refund was successful

=end

      def refund
        payment_application = PaymentApplication.find(params[:id])

        if payment_application.financial_txn.root_txn.txn_type.internal_identifier == 'credit_card'
          stripe_external_system = ExternalSystem.active.with_party_role(current_user.party.dba_organization, RoleType.iid('owner'))
          .where('internal_identifier = ?', 'stripe').first

          result = payment_application.financial_txn.refund(CompassAeBusinessSuite::ActiveMerchantWrappers::StripeWrapper,
                                                            {
                                                              private_key: stripe_external_system.private_key,
                                                              public_key: stripe_external_system.public_key
          })
        else
        	
        end

        render :json => {success: result[:success], message: result[:message]}
      end

=begin

  @api {get} /api/v1/payment_applications/:id/capture
  @apiVersion 1.0.0
  @apiName CapturePaymentApplication
  @apiGroup PaymentApplication

  @apiSuccess {Boolean} success True if the cpature was successful

=end

      def capture
        payment_application = PaymentApplication.find(params[:id])

        stripe_external_system = ExternalSystem.active.with_party_role(current_user.party.dba_organization, RoleType.iid('owner'))
        .where('internal_identifier = ?', 'stripe').first

        result = payment_application.financial_txn.capture(CompassAeBusinessSuite::ActiveMerchantWrappers::StripeWrapper,
                                                           {
                                                             private_key: stripe_external_system.private_key,
                                                             public_key: stripe_external_system.public_key
        })

        render :json => {success: result[:success], message: result[:message]}
      end


    end # PaymentApplicationsController
  end # V1
end # API
