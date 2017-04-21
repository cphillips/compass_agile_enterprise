
module ErpCommerce
  module Extensions
    module ProductOptionsControllerExtension

      private

      def new_product_option
        product_option = super

        if params[:price].present?
          product_option.set_default_price(params[:price])
        end

        product_option.save!

        product_option
      end

      def update_product_option
        product_option = super

        if params[:price].present?
          product_option.set_default_price(params[:price])
        end

        product_option.save!

        product_option
      end

    end # ProductOptionsControllerExtension
  end # Extensions
end # CompassAeBusinessSuite

API::V1::ProductOptionsController.prepend ErpCommerce::Extensions::ProductOptionsControllerExtension