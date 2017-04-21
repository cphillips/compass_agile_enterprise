class AddInventoryEntryToOrderLineItem < ActiveRecord::Migration
  def up
    unless column_exists? :order_line_items, :inventory_entry_id
      add_column :order_line_items, :inventory_entry_id, :integer
      add_column :order_line_items, :inventory_entry_description, :string

      add_index :order_line_items, :inventory_entry_id, name: 'oli_inv_entry_id_idx'
    end
  end

  def down
    if column_exists? :order_line_items, :inventory_entry_id
      remove_column :order_line_items, :inventory_entry_id
      remove_column :order_line_items, :inventory_entry_description
    end
  end
end
