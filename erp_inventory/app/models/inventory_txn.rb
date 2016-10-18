# create_table :inventory_txns do |t|
#   t.references :fixed_asset
#   t.references :inventory_entry

#   t.decimal :quantity
#   t.decimal :acutal_quantity
#   t.text :comments
#   t.boolean :is_sell
#   t.boolean :applied, default: false
#   t.datetime :applied_at

#   t.integer :created_by_id
#   t.string  :created_by_type
#

#   t.integer :tenant_id

#   t.text :custom_fields

# end

# add_index :inventory_txns, :fixed_asset_id, name: 'inv_txn_fixed_asset_idx'
# add_index :inventory_txns, :inventory_entry_id, name: 'inv_txn_inv_entry_idx'
# add_index :inventory_txns, :tenant_id, name: 'inv_txn_tenant_id_idx'

class InventoryTxn < ActiveRecord::Base
  attr_protected :created_at, :upated_at

  acts_as_biz_txn_event
  is_tenantable

  belongs_to :fixed_asset
  belongs_to :inventory_entry
  belongs_to :created_by, polymorphic: true

  after_create :update_inventory_available!
  before_destroy :unapply!, :revert_inventory_available!

  # Update number_available on InventoryEntry.
  # If the quantity is < 0 then update number available as it will be used
  #
  def update_inventory_available!
    if self.quantity < 0
      inventory_entry.number_available += self.quantity
      inventory_entry.save!
    end

    if is_sell?
      inventory_entry.number_sold += (0 - self.quantity)
      inventory_entry.save!
    end
  end

  # Revert the update on number_available on InventoryEntry
  #
  def revert_inventory_available!
    if applied
      inventory_entry.number_available -= self.quantity
      inventory_entry.save!
    end

    if is_sell?
      inventory_entry.number_sold -= (0 - self.quantity)
      inventory_entry.save!
    end
  end

  # Apply the transaction to the assoicated inventory
  #
  def apply!
    unless self.applied
      inventory_entry.number_in_stock += self.quantity
      inventory_entry.save!

      if self.quantity > 0
        inventory_entry.number_available += self.quantity
        inventory_entry.save!
      end

      self.applied = true
      self.applied_at = Time.now
      self.save!
    end
  end

  # Unapply the transaction to the assoicated inventory
  #
  def unapply!
    if self.applied
      inventory_entry.number_in_stock -= self.quantity
      inventory_entry.save!

      if self.quantity > 0
        inventory_entry.number_available -= self.quantity
        inventory_entry.save!
      end

      if is_sell?
        inventory_entry.number_sold -= (0 - self.quantity)
        inventory_entry.save!
      end

      self.applied = false
      self.applied_at = nil
      self.save!
    end
  end

end