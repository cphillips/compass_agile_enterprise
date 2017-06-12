OrderTxn.class_eval do

  # OVERRIDE
  # Update to all the addition of InventoryEntry records
  #
  # add product_type or product_instance line item
  #
  # @param [ProductType|ProductInstance|SimpleProductOffer] object the record being added
  # @param [Hash] opts the options for the item being added
  # @option opts [] :reln_type type of relationship to create if the item being added is a package of products
  # @option opts [] :to_role to role of relationship to create if the item being added is a package of products
  # @option opts [] :from_role from role of relationship to create if the item being added is a package of products
  # @option opts [] :selected_options product options selected for the item being added
  # @return [OrderLineItem]
  def add_line_item(object, opts={})
    if object.is_a?(Array)
      class_name = object.first.class.name
    else
      class_name = object.class.name
    end

    case class_name
    when 'InventoryEntry'
      line_item = add_inventory_entry_line_item(object, opts[:selected_product_options])
    when 'ProductType'
      line_item = add_product_type_line_item(object, opts[:selected_product_options], opts[:reln_type], opts[:to_role], opts[:from_role])
    when 'ProductInstance'
      line_item = add_product_instance_line_item(object, opts[:reln_type], opts[:to_role], opts[:from_role])
    when 'SimpleProductOffer'
      line_item = add_simple_product_offer_line_item(object)
    end

    # handle selected product options
    if opts[:selected_product_options]
      opts[:selected_product_options].each do |selected_product_option_hash|
        selected_product_option = line_item.selected_product_options.create(product_option_applicability_id: selected_product_option_hash[:product_option_applicability][:id])
        selected_product_option_hash[:selected_options].each do |selected_option|
          product_option = ProductOption.find(selected_option[:id])

          selected_product_option.product_options << product_option

          if selected_option[:price]
            charge_line = line_item.charge_lines.create!(description: product_option.description)
            charge_line.money = Money.create!(amount: selected_option[:price] * (opts[:quantity] || 1), currency: Currency.usd)
            charge_line.save!
          end

        end

        selected_product_option.save!
      end
    end

    if opts[:quantity]
      line_item.quantity = opts[:quantity]
    end

    line_item.save!

    line_item
  end

  def add_inventory_entry_line_item(inventory_entry, options)
    line_item = get_line_item_for_inventory_entry(inventory_entry, options)

    if line_item
      line_item.quantity += 1
      line_item.save
    else
      line_item = OrderLineItem.new
      line_item.inventory_entry_description = inventory_entry.description
      line_item.inventory_entry = inventory_entry
      line_item.product_type = inventory_entry.product_type
      line_item.product_type_description = inventory_entry.product_type.description
      line_item.sold_price = inventory_entry.try(:get_default_price).try(:money).try(:amount) || 0
      line_item.quantity = 1
      line_item.save
      line_items << line_item
    end

    line_item
  end

  def get_line_item_for_inventory_entry(inventory_entry, options)
    line_items.detect { |oli| oli.equals?(inventory_entry.id, options) }
  end

  # Update inventory based on the order lines in the OrderTxn.  This creates the InventoryTxns but does not apply them
  #
  def update_inventory!
    # TODO this needs to account for inventory at more than one location

    order_line_items.each do |order_line_item|
      if order_line_item.line_item_record.is_a? ProductType
        inventory_entry = order_line_item.line_item_record.inventory_entries.first

      elsif order_line_item.line_item_record.is_a? ProductInstance
        # first try to find inventory on the ProductInstance
        inventory_entry = order_line_item.line_item_record.inventory_entries.first

        # if nothing is found then find it on the Product Type
        unless inventory_entry
          inventory_entry = order_line_item.line_item_record.product_type.inventory_entries.first
        end

      elsif order_line_item.line_item_record.is_a? ProductOffer
        inventory_entry = order_line_item.line_item_record.product_type.inventory_entries.first

      elsif order_line_item.line_item_record.is_a? InventoryEntry
        inventory_entry = order_line_item.line_item_record

      end

      if inventory_entry
        order_line_item.inventory_txns.create!(
          quantity: (0 - order_line_item.quantity),
          is_sell: true,
          comments: "Online Sale #{self.description}",
          inventory_entry: inventory_entry,
          tenant_id: self.find_party_by_role('order_roles_dba_org').id
        )
      end

    end # order_line_items.each

  end # update_inventory

  # Apply any InventoryTxns associated to the OrderLineItems in this OrderTxn
  #
  def apply_inventory!
    # TODO this needs to account for inventory at more than one location

    order_line_items.each do |order_line_item|
      order_line_item.inventory_txns.each do |inventory_txn|
        inventory_txn.apply!
      end
    end # order_line_items.each
  end

  # Unapply any InventoryTxns associated to the OrderLineItems in this OrderTxn
  #
  def unapply_inventory!
    # TODO this needs to account for inventory at more than one location

    order_line_items.each do |order_line_item|
      order_line_item.inventory_txns.each do |inventory_txn|
        inventory_txn.unapply!
      end
    end # order_line_items.each
  end

end # class_eval

module ErpInventory
  module Extensions
    module OrderTxnExtension

      @@order_status_shipped_iids = ['sales_order_statuses_shipped']

      # Get all parties by thier roles for this order as there might be multiple depending on the products purchased
      #
      # @return [Array] Array of parties
      def parties_by_role_types(*role_types)
        parties = super(role_types)

        valid_order_line_items = order_line_items.select{|order_line_item| order_line_item.line_item_record.is_a? InventoryEntry}

        parties = []

        valid_order_line_items.each do |order_line_item|
          parties.push(order_line_item.inventory_entry.find_parties_by_role(role_types))
        end

        parties.flatten.compact.uniq
      end

      # Get line items grouped by a party role such as vendor
      #
      # @return [Array] Array of line items grouped for passed party roles such as vendor
      def line_items_by_party_roles(*role_types)
        _groups = super(role_types)

        valid_order_line_items = order_line_items.select{|order_line_item| order_line_item.line_item_record.is_a? InventoryEntry}

        groups = valid_order_line_items.group_by do |order_line_item|
          order_line_item.inventory_entry.find_party_by_role(role_types)
        end

        _groups.merge(groups)
      end

      # set current status of entity.
      #
      # This is overriding the default method to apply any inventory if a status of shipped is set and
      # unapply inventory if it is updated from shipped
      #
      # @param args [String, TrackedStatusType, Array] This can be a string of the internal identifier of the
      # TrackedStatusType to set, a TrackedStatusType instance, or three params the status, options and party_id
      def current_status=(args)
        if args.is_a?(Array)
          status = args[0]
        else
          status = args
        end

        tracked_status_type = status.is_a?(TrackedStatusType) ? status : TrackedStatusType.find_by_internal_identifier(status.to_s)
        raise "TrackedStatusType does not exist #{status.to_s}" unless tracked_status_type

        # if passed status is current status then do nothing
        unless self.current_status_type && (self.current_status_type.id == tracked_status_type.id)
          if self.current_status_type
            _current_status = self.current_status_type.internal_identifier
          else
            _current_status = nil
          end
          super(args)

          if args.is_a?(Array)
            status = args[0]
          else
            status = args
          end

          if status.is_a? TrackedStatusType
            status = status.internal_identifier
          end

          if @@order_status_shipped_iids.include?(status)
            self.apply_inventory!
          else
            # if there were InventoryTxns that were applied and this task went from complete to pending we
            # need to unapply those InventoryTxns
            if _current_status && @@order_status_shipped_iids.include?(_current_status)
              self.unapply_inventory!
            end
          end
        end
      end

    end # OrderTxnExtension
  end # Extensions
end # ErpInventory

OrderTxn.prepend ErpInventory::Extensions::OrderTxnExtension
