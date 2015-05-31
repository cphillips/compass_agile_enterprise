# create_table :order_line_items do |t|
#   t.integer  	  :order_txn_id
#   t.integer  	  :order_line_item_type_id
#   t.integer     :product_offer_id
#   t.string      :product_offer_description
#   t.integer     :product_instance_id,
#   t.string      :product_instance_description
#   t.integer     :product_type_id
#   t.string      :product_type_description
#   t.decimal  	  :sold_price, :precision => 8, :scale => 2
#   t.integer	    :sold_price_uom
#   t.integer  	  :sold_amount
#   t.integer     :sold_amount_uom
#   t.integer     :quantity
#   t.integer     :unit_of_measurement_id
#   t.decimal     :unit_price, :precision => 8, :scale => 2
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

  belongs_to :order_txn, :class_name => 'OrderTxn'
  belongs_to :order_line_item_type

  has_many :charge_lines, :as => :charged_item, :dependent => :destroy

  belongs_to :product_instance
  belongs_to :product_type
  belongs_to :product_offer

  has_many :order_line_item_pty_roles, :dependent => :destroy
  has_many :role_types, :through => :order_line_item_pty_roles

  ## Allow for polymorphic subtypes of this class
  belongs_to :order_line_record, :polymorphic => true

  before_destroy :destroy_order_line_item_relationships

  # helper method to get dba_organization related to this order_line_item
  def dba_organization
    order_txn.find_party_by_role('dba_org')
  end

  def destroy_order_line_item_relationships
    OrderLineItemRelationship.where("order_line_item_id_from = ? or order_line_item_id_to = ?", self.id, self.id).destroy_all
  end

  # get the total charges for a order_line_item.
  # The total will be returned as Money.
  # There may be multiple Monies assocated with an order, such as points and
  # dollars. To handle this, the method should return an array of Monies
  # if a currency is passed in return the amount for only that currency
  def total_amount(currency=nil)
    if currency and currency.is_a?(String)
      currency = Currency.send(currency)
    end

    charges = {}

    # get sold price
    # TODO currency will eventually need to be accounted for here.  Solid price should probably be a money record
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

    # if currency was based only return that amount
    # if there is only one currency then return that amount
    # if there is more than once currency return the hash
    if currency
      charges[currency.internal_identifier][:amount]
    elsif charges.keys.count == 1
      charges
    end
  end

  # Alias for to_s
  def to_label
    to_s
  end

  # description of line_item_record
  def to_s
    line_item_record.description
  end

  # determine the record this OrderLineItem pertains to
  # can be a ProductOffer, ProductInstance or ProductType
  def line_item_record
    if product_offer
      product_offer
    else
      if product_instance
        product_instance
      else
        product_type
      end
    end
  end

  def clone
    order_line_item_dup = dup
    order_line_item_dup.order_txn_id = nil

    order_line_item_dup
  end

end
