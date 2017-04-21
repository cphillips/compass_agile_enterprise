# create_table :order_line_items do |t|
#   t.integer     :order_txn_id
#   t.integer     :order_line_item_type_id
#   t.integer     :product_offer_id
#   t.string      :product_offer_description
#   t.integer     :product_instance_id,
#   t.string      :product_instance_description
#   t.integer     :product_type_id
#   t.string      :product_type_description
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

class OrderLineItem < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  tracks_created_by_updated_by

  belongs_to :order_txn, :class_name => 'OrderTxn'
  belongs_to :order_line_item_type

  has_many :charge_lines, :as => :charged_item, :dependent => :destroy

  belongs_to :product_instance
  belongs_to :product_type
  belongs_to :product_offer

  has_many :order_line_item_pty_roles, :dependent => :destroy
  has_many :role_types, :through => :order_line_item_pty_roles
  has_many :sales_tax_lines, as: :taxed_record, dependent: :destroy

  ## Allow for polymorphic subtypes of this class
  belongs_to :order_line_record, :polymorphic => true

  has_many :selected_product_options, as: :selected_option_record, dependent: :destroy

  before_destroy :destroy_order_line_item_relationships

  def taxed?
    line_item_record.taxable?
  end

  # helper method to get dba_organization related to this order_line_item
  def dba_organization
    order_txn.find_party_by_role('dba_org')
  end
  alias :tenant :dba_organization

  def destroy_order_line_item_relationships
    OrderLineItemRelationship.where("order_line_item_id_from = ? or order_line_item_id_to = ?", self.id, self.id).destroy_all
  end

  # get the total charges for a order_line_item.
  # The total will be returned as Money.
  # There may be multiple Monies assocated with an order, such as points and
  # dollars. To handle this, the method should return an array of Monies
  # if a currency is passed in return the amount for only that currency
  def total_amount(currency=Currency.usd)
    if currency and currency.is_a?(String)
      currency = Currency.send(currency)
    end

    charges = {}

    # get sold price
    # TODO currency will eventually need to be accounted for here.  Sold price should probably be a money record
    if self.sold_price
      charges["USD"] ||= {amount: 0}
      charges["USD"][:amount] += (self.sold_price * (self.quantity || 1))
    end

    # get all of the charge lines associated with the order_line
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

    # if there was no sold price and no charges set a default of USD = 0
    if charges.empty?
      charges["USD"] = {amount: 0}
    end

    # if currency was passed only return that amount
    # if there is only one currency then return that amount
    # if there is more than once currency return the hash
    if currency
      charges[currency.internal_identifier][:amount].round(2)
    elsif charges.keys.count == 1
      charges
    end
  end

  # calculates tax and save to sales_tax
  def calculate_tax!(ctx={})
    taxation = ErpOrders::Services::Taxation.new
    tax = 0

    if self.taxed?
      tax = taxation.calculate_tax!(self, ctx.merge({amount: (self.sold_price * (self.quantity || 1))}))
    end

    # only get charges that are USD currency
    charge_lines.joins(:money).joins(:charge_type)
    .where('money.currency_id' => Currency.usd)
    .where('charge_types.taxable' => true).readonly(false).each do |charge_line|
      tax += charge_line.calculate_tax!(ctx)
    end

    self.sales_tax = tax
    self.save

    tax
  end

  # Alias for to_s
  def to_label
    to_s
  end

  # description of line_item_record
  def to_s
    if line_item_record
      line_item_record.description
    else
      nil
    end
  end

  # determine the record this OrderLineItem pertains to
  # can be a ProductOffer, ProductInstance or ProductType
  def line_item_record
    if product_offer
      product_offer
    else
      if inventory_entry
        inventory_entry
      elsif product_instance
        product_instance
      else
        product_type
      end
    end
  end

  def add_party_with_role(party, role_type)
    unless order_line_item_pty_roles.joins(:role_type).where(party_id: party).where(role_types: {internal_identifier: role_type}).first
      order_line_item_pty_roles.create(party: party, role_type: RoleType.iid(role_type))
    end
  end

  def find_party_by_role(role_type)
    order_line_item_pty_role = order_line_item_pty_roles.joins(:role_type).where(party_id: party).where(role_types: {internal_identifier: role_type}).first

    if order_line_item_pty_role
      order_line_item_pty_role.party
    end
  end

  def clone
    order_line_item_dup = dup
    order_line_item_dup.order_txn_id = nil

    order_line_item_dup
  end

  # Check if this Order Line Item is equal by product type and options selected
  #
  # @param {Integer} product_type Product type
  # @param {Array} options Array of options
  # @return {Boolean} true if it is equal
  def equals?(product_type, options)
    equal = true;

    if self.product_type.id == product_type.id
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

  def to_data_hash
    data = {
      id: id,
      sold_price: sold_price,
      total_amount: total_amount,
      quantity: quantity
    }

    data[:product_type] = line_item_record.to_data_hash

    data[:selected_product_options] = self.selected_product_options.collect(&:to_mobile_data_hash)

    data
  end
  alias :to_mobile_hash :to_data_hash

end
