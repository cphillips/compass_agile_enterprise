InventoryEntry.class_eval do
  acts_as_priceable
end

module ErpCommerce
  module Extensions
    module InventoryEntryExtension

      # Override from base class, converts model to data hash
      #
      # @return [Hash] Data hash for this model
      def to_data_hash
        data = super

        if get_default_price
          data[:price] = get_default_price.try(:money).try(:amount)
        end

        data
      end

      def get_default_price
        pricing_plan = self.pricing_plans.first

        if pricing_plan
          self.pricing_plans.first.get_price
        else
          self.product_type.get_default_price
        end
      end

      def get_current_simple_plan
        plan = self.pricing_plans.where('is_simple_amount = ? and (from_date <= ? and thru_date >= ? or (from_date is null and thru_date is null))', true, Date.today, Date.today).first

        unless plan
          plan = self.product_type.get_current_simple_plan
        end

        plan
      end

    end # UserExtension
  end # Extensions
end # ErpCommerce

InventoryEntry.prepend ErpCommerce::Extensions::InventoryEntryExtension
