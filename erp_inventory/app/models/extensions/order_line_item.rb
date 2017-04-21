# create_table :order_line_items do |t|
#   t.integer     :order_txn_id
#   t.integer     :order_line_item_type_id
#   t.integer     :product_offer_id
#   t.string      :product_offer_description
#   t.integer     :product_instance_id,
#   t.string      :product_instance_description
#   t.integer     :product_type_id
#   t.string      :product_type_description

#   t.integer     :inventory_entry_id
#   t.integer     :inventory_entry_description

#   t.decimal     :sold_price, :precision => 8, :scale => 2
#   t.integer     :sold_price_uom
#   t.integer     :sold_amount
#   t.integer     :sold_amount_uom
#   t.integer     :quantity
#   t.integer     :unit_of_measurement_id
#   t.decimal     :unit_price, :precision => 8, :scale => 2
#   t.boolean     :taxable
#   t.decimal     :sales_tax, :precision => 8, :scale => 2
#
#   t.timestamps
# end
#
# add_index :order_line_items, :order_txn_id
# add_index :order_line_items, :order_line_item_type_id
# add_index :order_line_items, :product_instance_id
# add_index :order_line_items, :product_type_id
# add_index :order_line_items, :product_offer_id
# add_index :order_line_items, :inventory_entry_id

OrderLineItem.class_eval do
  has_many :inventory_txns, as: :created_by, dependent: :destroy

  belongs_to :inventory_entry

  # OVERRIDE
  # Override to find ProductType through an InventoryEntry if it is present
  #
  def product_type
    if product_type_id
      ProductType.find(product_type_id)
    elsif !inventory_entry_id.nil?
      inventory_entry.product_type
    else
      nil
    end
  end

  # OVERRIDE
  # Override to check InventoryEntry as well as ProductType
  #
  # Check if this Order Line Item is equal by product type and options selected
  #
  # @param {Integer} record Record to check
  # @param {Array} options Array of options
  # @return {Boolean} true if it is equal
  def equals?(record, options)
    equal = true;

    if ((record.is_a? ProductType) && (self.product_type_id == record.id)) || ((record.is_a? InventoryEntry) && (self.inventory_entry_id == record.inventory_entry_id))

      self.selected_product_options.each do |selected_product_option|
        passed_option = options.find{ |option| selected_product_option.product_option_applicability_id == option[:product_option_applicability][:id] }

        if passed_option

          if passed_option[:selected_options].length != selected_product_option.product_options.length
            equal = false;

            break
          else
            passed_option[:selected_options].each do |_selected_option|
              selected_option = selected_product_option.product_options.find{ |option| option.id == _selected_option[:id] }

              unless selected_option

                equal = false;

                break

              end
            end
          end

          if !equal
            break
          end

        else
          equal = false

          break
        end

      end

    else
      equal = false
    end

    equal
  end
end

module ErpInventory
  module Extensions
    module OrderLineItemExtension

      # Override from base class, converts model to data hash
      #
      # @return [Hash] Data hash for this model
      def to_data_hash
        data = super

        data[:inventory_entry] = self.try(:inventory_entry).try(:to_data_hash)

        data
      end

    end # UserExtension
  end # Extensions
end # ErpInventory

OrderLineItem.prepend ErpInventory::Extensions::OrderLineItemExtension
