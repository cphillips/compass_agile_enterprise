# Table Definition ##########################################
# create_table :order_txns do |t|
#   t.column    :description,         :string
#   t.column    :order_txn_type_id,   :integer
#
#   # Multi-table inheritance info
#   t.column    :order_txn_record_id,   :integer
#   t.column    :order_txn_record_type, :string
#
#   # Contact Information
#   t.column    :email,              :string
#   t.column    :phone_number,       :string
#
#   # Shipping Address
#   t.column    :ship_to_first_name,     :string
#   t.column    :ship_to_last_name,      :string
#   t.column    :ship_to_address_line_1, :string
#   t.column    :ship_to_address_line_2, :string
#   t.column    :ship_to_city,           :string
#   t.column    :ship_to_state,          :string
#   t.column    :ship_to_postal_code,    :string
#   t.column    :ship_to_country,        :string
#
#   # Private parts
#   t.column    :customer_ip,           :string
#   t.column    :order_number,          :string
#   t.column    :error_message,         :string
#
#   t.timestamps
# end
#
# add_index :order_txns, :order_txn_type_id
# add_index :order_txns, [:order_txn_record_id, :order_txn_record_type], :name => 'order_txn_record_idx'
#
# add_index :order_txns, :order_txn_type_id
# add_index :order_txns, [:order_txn_record_id, :order_txn_record_type], :name => 'order_txn_record_idx'

class OrderTxn < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  acts_as_biz_txn_event

  belongs_to :order_txn_record, polymorphic: true
  has_many :order_line_items, dependent: :destroy
  has_many :charge_lines, as: :charged_item, dependent: :destroy

  alias :line_items :order_line_items

  # validation
  validates_format_of :email, :with => /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i, :on => :update, :allow_nil => true
  validates :order_number, {uniqueness: true, :allow_nil => true}

  class << self
    # Filter records
    #
    # @param filters [Hash] a hash of filters to be applied,
    # @param statement [ActiveRecord::Relation] the query being built
    # @return [ActiveRecord::Relation] the query being built
    def apply_filters(filters, statement=nil)
      unless statement
        statement = OrderTxn
      end

      if filters[:user_id]
        statement = statement.joins(biz_txn_event: :biz_txn_party_roles)
        .where(biz_txn_party_roles: {party_id: User.find(filters[:user_id]).party}).uniq
      end

      if filters[:status]
        if filters[:status].is_a? Array
          status = filters[:status]
        else
          status = [filters[:status]]
        end

        statement = statement.with_current_status(status)
      end

      if filters[:not_status]
        if filters[:not_status].is_a? Array
          not_status = filters[:not_status]
        else
          not_status = [filters[:not_status]]
        end

        statement = statement.without_current_status(not_status)
      end

      statement
    end

    #
    # scoping helpers
    #

    # scope by dba organization
    #
    # @param dba_organization [Party] dba organization to scope by
    #
    # @return [ActiveRecord::Relation]
    def scope_by_dba_organization(dba_organization)
      role_type_parent = BizTxnPartyRoleType.iid('order_roles')
      biz_txn_party_role_type = BizTxnPartyRoleType.find_or_create('order_roles_dba_org',
                                                                   'Doing Business As Organization',
                                                                   role_type_parent)

      scope_by_party(dba_organization, {role_types: [biz_txn_party_role_type]})
    end
    alias scope_by_dba scope_by_dba_organization

    # scope by party
    #
    # @param party [Integer | Party | Array] either a id of Party record, a Party record, an array of Party records
    # or an array of Party ids
    # @param options [Hash] options to apply to this scope
    # @option options [Array] :role_types role types to include in the scope
    #
    # @return [ActiveRecord::Relation]
    def scope_by_party(party, options={})
      statement = joins(biz_txn_event: :biz_txn_party_roles)
      .where(biz_txn_party_roles: {party_id: party}).uniq

      if options[:role_types]
        statement = statement.where(biz_txn_party_roles: {biz_txn_party_role_type_id: options[:role_types]})
      end

      statement
    end

    # find a order by given biz txn party role iid and party
    #
    def find_by_party_role(biz_txn_party_role_type_iid, party)
      BizTxnPartyRole.where('party_id = ? and biz_txn_party_role_type_id = ?', party.id, BizTxnPartyRoleType.find_by_internal_identifier(biz_txn_party_role_type_iid).id).all.collect { |item| item.biz_txn_event.biz_txn_record }
    end

    def next_order_number
      max_id = maximum('id')

      if max_id
        max_id = max_id + 1
      else
        max_id = 1
      end

      current_order = where(OrderTxn.arel_table[:order_number].matches("%#{max_id}%")).first

      if current_order
        while current_order
          max_id = max_id + 1
          current_order = where(OrderTxn.arel_table[:order_number].matches("%#{max_id}%")).first
        end
      end

      "#{max_id}"
    end
  end

  # helper method to get dba_organization related to this order_txn
  def dba_organization
    find_party_by_role('order_roles_dba_org')
  end
  alias :tenant :dba_organization

  # get the total charges for an order.
  # The total will be returned as Money.
  # There may be multiple Monies associated with an order, such as points and
  # dollars. To handle this, the method should return an array of Monies
  # if a currency is passed in return the amount for only that currency
  def total_amount(currency=Currency.usd)
    if currency and currency.is_a?(String)
      currency = Currency.send(currency)
    end

    charges = {"USD" => {amount: 0}}
    # get any charges directly on this order_txn or on order_line_items
    charge_lines.each do |charge|
      charge_money = charge.money

      total_by_currency = charges[charge_money.currency.internal_identifier]
      unless total_by_currency
        total_by_currency = {
          amount: 0
        }
      end

      total_by_currency[:amount] += charge_money.amount unless charge_money.amount.nil?

      charges[charge_money.currency.internal_identifier] = total_by_currency
    end

    # TODO currency will eventually need to be accounted for here.
    charges["USD"][:amount] += line_items.sum(&:total_amount).round(2)

    # add tax
    charges["USD"][:amount] += (self.sales_tax.nil? ? 0 : self.sales_tax)

    if charges.empty?
      0
    else
      # if currency was based only return that amount
      # if there is only one currency then return that amount
      # if there is more than once currency return the hash
      if currency
        charges[currency.internal_identifier][:amount].round(2)
      else
        charges
      end
    end
  end

  def sub_total(currency=Currency.usd)
    line_items.collect { |item| item.total_amount(currency) }.inject(:+)
  end

  # gets the total amount of payments made against this order via charge line payments
  def total_payment_amount
    amount = all_charge_lines.collect(&:total_payments).inject(:+)
    if amount.nil?
      0
    else
      amount
    end
  end

  # gets total amount due (total_amount - total_payments)
  # only returns Currency USD
  def total_amount_due
    if total_amount(Currency.usd)
      total_amount(Currency.usd) - total_payment_amount
    else
      0
    end
  end

  # get all charge lines on order and order line items
  def all_charge_lines
    all_charges = []
    all_charges.concat(charge_lines)
    order_line_items.each do |line_item|
      all_charges.concat(line_item.charge_lines)
    end
    all_charges
  end

  # get the total quantity of this order
  def total_quantity
    order_line_items.pluck(:quantity).inject(:+)
  end

  # calculates tax for each line item and save to sales_tax
  def calculate_tax!(ctx)
    tax = 0
    order_line_items.select { |line_item| line_item.taxed? }.each do |line_item|
      tax += line_item.calculate_tax!(ctx)
    end

    # only get charges that are USD currency
    charge_lines.joins(:money)
    .joins(:charge_type)
    .where('money.currency_id' => Currency.usd)
    .where('charge_types.taxable' => true).readonly(false).each do |charge_line|
      tax += charge_line.calculate_tax!(ctx)
    end

    self.sales_tax = tax
    self.save

    tax
  end

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
      line_item = add_inventory_entry_line_item(object)
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

  def add_simple_product_offer_line_item(simple_product_offer)
    line_item = get_line_item_for_simple_product_offer(simple_product_offer)

    product_type = simple_product_offer.product_type

    if line_item
      line_item.quantity += 1
      line_item.save
    else
      line_item = OrderLineItem.new
      line_item.product_type = product_type
      line_item.product_offer = simple_product_offer.product_offer
      line_item.sold_price = simple_product_offer.get_current_simple_plan.money_amount
      line_item.quantity = 1
      line_item.save
      line_items << line_item
    end

    line_item
  end

  def add_product_type_line_item(product_type, options=[], reln_type = nil, to_role = nil, from_role = nil)
    if (product_type.is_a?(Array))
      if (product_type.size == 0)
        return
      elsif (product_type.size == 1)
        product_type_for_line_item = product_type[0]
      else # more than 1 in the array, so it's a package
        product_type_for_line_item = ProductType.new
        product_type_for_line_item.description = to_role.description

        product_type.each do |product|
          # make a product-type-reln
          reln = ProdTypeReln.new
          reln.prod_type_reln_type = reln_type
          reln.role_type_id_from = from_role.id
          reln.role_type_id_to = to_role.id

          #associate package on the "to" side of reln
          reln.prod_type_to = product_type_for_line_item

          #assocation product_type on the "from" side of the reln
          reln.prod_type_from = product
          reln.save
        end
      end
    else
      product_type_for_line_item = product_type
    end

    line_item = get_line_item_for_product_type(product_type_for_line_item, options)

    if line_item
      line_item.quantity += 1
      line_item.save
    else
      line_item = OrderLineItem.new
      line_item.product_type = product_type_for_line_item
      line_item.sold_price = product_type_for_line_item.get_current_simple_plan.money_amount
      line_item.quantity = 1
      line_item.save
      line_items << line_item
    end

    line_item
  end

  def add_product_instance_line_item(product_instance, reln_type = nil, to_role = nil, from_role = nil)
    li = OrderLineItem.new

    if (product_instance.is_a?(Array))
      if (product_instance.size == 0)
        return
      elsif (product_instance.size == 1)
        product_instance_for_line_item = product_instance[0]
      else # more than 1 in the array, so it's a package
        product_instance_for_line_item = ProductInstance.new
        product_instance_for_line_item.description = to_role.description
        product_instance_for_line_item.save

        product_instance.each do |product|
          # make a product-type-reln
          reln = ProdInstanceReln.new
          reln.prod_instance_reln_type = reln_type
          reln.role_type_id_from = from_role.id
          reln.role_type_id_to = to_role.id

          #associate package on the "to" side of reln
          reln.prod_instance_to = product_instance_for_line_item

          #assocation product_instance on the "from" side of the reln
          reln.prod_instance_from = product
          reln.save
        end
      end
    else
      product_instance_for_line_item = product_instance
    end

    li.product_instance = product_instance_for_line_item
    self.line_items << li
    li.save

    li
  end

  def get_line_item_for_product_type(product_type, options)
    line_items.detect { |oli| oli.equals?(product_type, options) }
  end

  def get_line_item_for_simple_product_offer(simple_product_offer)
    line_items.detect { |oli| oli.product_offer.product_offer_record == simple_product_offer }
  end

  # Get all parties by thier roles for this order as there might be multiple depending on the products purchased
  #
  # @return [Array] Array of parties
  def parties_by_role_types(*role_types)
    role_types = role_types.flatten

    valid_order_line_items = order_line_items.select{|order_line_item| order_line_item.line_item_record.is_a? ProductType}

    parties = []

    valid_order_line_items.each do |order_line_item|
      parties.push(order_line_item.product_type.find_parties_by_role(role_types))
    end

    parties.flatten.compact.uniq
  end

  # Get line items grouped by a party role such as vendor
  #
  # @return [Array] Array of line items grouped for passed party roles such as vendor
  def line_items_by_party_roles(*role_types)
    role_types = role_types.flatten

    valid_order_line_items = order_line_items.select{|order_line_item| order_line_item.line_item_record.is_a? ProductType}

    valid_order_line_items.group_by do |order_line_item|
      order_line_item.product_type.find_party_by_role(role_types)
    end
  end

  def set_shipping_info(party)
    self.ship_to_first_name = party.business_party.current_first_name
    self.ship_to_last_name = party.business_party.current_last_name
    shipping_address = party.find_contact_with_purpose(PostalAddress, ContactPurpose.shipping) || party.find_contact_with_purpose(PostalAddress, ContactPurpose.default)

    unless shipping_address.nil?
      shipping_address = shipping_address.contact_mechanism
      self.ship_to_address_line_1 = shipping_address.address_line_1
      self.ship_to_address_line_2 = shipping_address.address_line_2
      self.ship_to_city = shipping_address.city
      self.ship_to_state = shipping_address.state
      self.ship_to_postal_code = shipping_address.zip
      # self.ship_to_country_name = shipping_address.country_name
      self.ship_to_country = shipping_address.country
    end
  end

  # True if there is shipping info
  #
  def has_shipping_info?
    !ship_to_address_line_1.nil?
  end

  # Get shipping info formatted for HTML
  #
  def shipping_info
    if has_shipping_info?

      info = "#{ship_to_first_name} #{ship_to_last_name}<br>#{ship_to_address_line_1}"

      if ship_to_address_line_2.present?
        info << "<br>#{ship_to_address_line_2}"
      end

      info << "<br>#{ship_to_city} #{ship_to_state} #{ship_to_postal_code}<br>#{ship_to_country}"

    else
      info = ''
    end
    info
  end

  def set_billing_info(party)
    self.email = party.find_contact_mechanism_with_purpose(EmailAddress, ContactPurpose.billing).email_address unless party.find_contact_mechanism_with_purpose(EmailAddress, ContactPurpose.billing).nil?
    self.phone_number = party.find_contact_mechanism_with_purpose(PhoneNumber, ContactPurpose.billing).phone_number unless party.find_contact_mechanism_with_purpose(PhoneNumber, ContactPurpose.billing).nil?

    self.bill_to_first_name = party.business_party.current_first_name
    self.bill_to_last_name = party.business_party.current_last_name
    billing_address = party.find_contact_with_purpose(PostalAddress, ContactPurpose.billing) || party.find_contact_with_purpose(PostalAddress, ContactPurpose.default)
    unless billing_address.nil?
      billing_address = billing_address.contact_mechanism
      self.bill_to_address_line_1 = billing_address.address_line_1
      self.bill_to_address_line_2 = billing_address.address_line_2
      self.bill_to_city = billing_address.city
      self.bill_to_state = billing_address.state
      self.bill_to_postal_code = billing_address.zip
      # self.bill_to_country_name = billing_address.country_name
      self.bill_to_country = billing_address.country
    end
  end

  # Get billing info formatted for HTML
  #
  def billing_info
    info = "#{bill_to_first_name} #{bill_to_last_name}<br>#{bill_to_address_line_1}<br>"

    if bill_to_address_line_2.present?
      info << "<br>#{bill_to_address_line_2}"
    end

    info << "<br>#{bill_to_city} #{bill_to_state} #{bill_to_postal_code}<br>#{bill_to_country}"

    info
  end

  def determine_txn_party_roles
    #Template Method
  end

  def determine_charge_elements
    #Template Method
  end

  def determine_charge_accounts
    #Template Method
  end

  #
  # BizTxnEvent Overrides
  #

  def create_dependent_txns
    #Template Method
  end

  #
  # Payment methods
  # these methods are used to capture payments on orders
  #

  def authorize_payments(financial_txns, credit_card, gateway, gateway_options={}, use_delayed_jobs=true)
    all_txns_authorized = true
    authorized_txns = []
    gateway_message = nil

    #check if we are using delayed jobs or not
    unless use_delayed_jobs
      financial_txns.each do |financial_txn|
        financial_txn.authorize(credit_card, gateway, gateway_options)
        if financial_txn.payments.empty?
          all_txns_authorized = false
          gateway_message = 'Unknown Gateway Error'
          break
        elsif !financial_txn.payments.first.success
          all_txns_authorized = false
          gateway_message = financial_txn.payments.first.payment_gateways.first.response
          break
        else
          authorized_txns << financial_txn
        end
      end
    else
      financial_txns.each do |financial_txn|
        #push into delayed job so we can fire off more payments if needed
        ErpTxnsAndAccts::DelayedJobs::PaymentGatewayJob.start(financial_txn, gateway, :authorize, gateway_options, credit_card)
      end
      #wait till all payments are complete
      #wait a max of 120 seconds 2 minutes
      wait_counter = 0
      while !all_payment_jobs_completed?(financial_txns, :authorized)
        break if wait_counter == 40
        sleep 3
        wait_counter += 1
      end

      result, gateway_message, authorized_txns = all_payment_jobs_successful?(financial_txns)

      unless result
        all_txns_authorized = false
      end
    end
    return all_txns_authorized, authorized_txns, gateway_message
  end

  def capture_payments(authorized_txns, credit_card, gateway, gateway_options={}, use_delayed_jobs=true)
    all_txns_captured = true
    gateway_message = nil

    #check if we are using delayed jobs or not
    unless use_delayed_jobs
      authorized_txns.each do |financial_txn|
        result = financial_txn.capture(credit_card, gateway, gateway_options)
        unless (result[:success])
          all_txns_captured = false
          gateway_message = result[:gateway_message]
          break
        end
      end
    else
      authorized_txns.each do |financial_txn|
        #push into delayed job so we can fire off more payments if needed
        ErpTxnsAndAccts::DelayedJobs::PaymentGatewayJob.start(financial_txn, gateway, :capture, gateway_options, credit_card)
      end

      #wait till all payments are complete
      #wait a max of 120 seconds 2 minutes
      wait_counter = 0
      while !all_payment_jobs_completed?(authorized_txns, :captured)
        break if wait_counter == 40
        sleep 3
        wait_counter += 1
      end

      result, gateway_message, authorized_txns = all_payment_jobs_successful?(authorized_txns)

      unless result
        all_txns_captured = false
      end
    end

    return all_txns_captured, gateway_message
  end

  def rollback_authorizations(authorized_txns, credit_card, gateway, gateway_options={}, use_delayed_jobs=true)
    all_txns_rolledback = true

    #check if we are using delayed jobs or not
    unless use_delayed_jobs
      authorized_txns.each do |financial_txn|
        result = financial_txn.reverse_authorization(credit_card, gateway, gateway_options)
        unless (result[:success])
          all_txns_rolledback = false
        end
      end
    else
      authorized_txns.each do |financial_txn|
        #push into delayed job so we can fire off more payments if needed
        ErpTxnsAndAccts::DelayedJobs::PaymentGatewayJob.start(financial_txn, gateway, :reverse_authorization, gateway_options, credit_card)
      end

      #wait till all payments are complete
      #wait a max of 120 seconds 2 minutes
      wait_counter = 0
      while !all_payment_jobs_completed?(authorized_txns, :authorization_reversed)
        break if wait_counter == 40
        sleep 3
        wait_counter += 1
      end

      result, gateway_message, authorized_txns = all_payment_jobs_successful?(authorized_txns)

      unless result
        all_txns_rolledback = false
      end
    end

    all_txns_rolledback
  end

  def all_payment_jobs_completed?(financial_txns, state)
    result = true

    #check the financial txns as they come back
    financial_txns.each do |financial_txn|
      payments = financial_txn.payments(true)
      if payments.empty? || payments.first.current_state.to_sym != state
        result = false
        break
      end
    end

    result
  end

  def all_payment_jobs_successful?(financial_txns)
    result = true
    message = nil
    authorized_txns = []

    #check the financial txns to see all were successful, if not get message
    financial_txns.each do |financial_txn|
      payments = financial_txn.payments(true)
      if payments.empty? || !payments.first.success
        result = false
        unless payments.empty?
          message = financial_txn.payments.first.payment_gateways.first.response
        else
          message = "Unknown Protobase Error"
        end
      else
        authorized_txns << financial_txn
      end
    end

    return result, message, authorized_txns
  end

  # Clone this OrderTxn and its OrderLineItems
  #
  # @param [Hash] opts Options for the clone
  # @option opts [Party] :dba_organization The DBA Org to set for the clone, if not passed it will default to the current DBA Org for the cloned OrderTxn
  # @option opts [BizTxnType] :biz_txn_type The BizTxnType to set for the clone, if not passed it will default to the current OrderTxns BizTxnType
  # @option opts [String] :status The status to initialize this OrderTxn with
  # @return [OrderTxn]
  def clone(opts={})
    order_txn_dup = dup
    order_txn_dup.order_txn_record_id = nil
    order_txn_dup.order_txn_record_type = nil
    order_txn_dup.order_number = OrderTxn.next_order_number
    order_txn_dup.error_message = nil
    order_txn_dup.payment_gateway_txn_id = nil
    order_txn_dup.credit_card_id = nil
    order_txn_dup.initialize_biz_txn_event
    order_txn_dup.root_txn.description = self.biz_txn_event.description

    if opts[:biz_txn_type]
      order_txn_dup.root_txn.biz_txn_type = opts[:biz_txn_type]
    else
      order_txn_dup.root_txn.biz_txn_type = self.root_txn.biz_txn_type
    end

    # add a relationship describing the original and the clone
    biz_txn_rel_type = BizTxnRelType.find_or_create('cloned_from', 'Cloned From', nil)
    BizTxnRelationship.create(txn_event_to: self.root_txn,
                              txn_event_from: order_txn_dup.root_txn,
                              biz_txn_rel_type: biz_txn_rel_type)


    order_line_item_rel_type = OrderLineItemRelType.find_or_create('cloned_from', 'Cloned From', nil)

    self.order_line_items.each do |order_line_item|
      order_line_item_clone = order_line_item.clone
      order_txn_dup.order_line_items << order_line_item_clone

      OrderLineItemRelationship.create(order_line_item_from: order_line_item_clone,
                                       order_line_item_to: order_line_item,
                                       order_line_item_rel_type: order_line_item_rel_type)

    end

    order_txn_dup.save!

    if opts[:status]
      order_txn_dup.current_status = opts[:status]
    end

    if opts[:dba_organization]
      order_txn_dup.root_txn.add_party_with_role(opts[:dba_organization], 'order_roles_dba_org')
    else
      order_txn_dup.root_txn.add_party_with_role(self.root_txn.find_party_by_role('order_roles_dba_org'), 'order_roles_dba_org')
    end

    order_txn_dup
  end

  def to_label
    self.order_number
  end

  def to_data_hash
    data = to_hash({only: [:id, :description, :order_number,
                           :ship_to_address_line_1, :ship_to_address_line_2, :ship_to_city,
                           :ship_to_state, :ship_to_postal_code, :ship_to_country,
                           :bill_to_address_line_1, :bill_to_address_line_2, :bill_to_city,
                           :bill_to_state, :bill_to_postal_code, :bill_to_country],
                    sub_total: sub_total,
                    amount: total_amount,
                    status: current_status_application.try(:tracked_status_type).try(:description)})

    data[:charge_lines] = charge_lines.collect(&:to_data_hash)

    data[:order_line_items] = order_line_items.collect(&:to_data_hash)

    if find_party_by_role('order_roles_customer')
      data[:customer_party_id] = find_party_by_role('order_roles_customer').id
    end

    data
  end
  alias :to_mobile_hash :to_data_hash

end
