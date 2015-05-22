class AddChargeTypeToChargeLines < ActiveRecord::Migration
  def change
    add_column :charge_lines, :charge_type_id, :integer unless column_exists?(:charge_lines, :charge_type_id)
  end
end
