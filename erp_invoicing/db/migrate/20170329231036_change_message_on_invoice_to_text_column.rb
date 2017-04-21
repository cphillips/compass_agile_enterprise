class ChangeMessageOnInvoiceToTextColumn < ActiveRecord::Migration
  def up
  	change_column :invoices, :message, :text 
  end

  def down
  	change_column :invoices, :message, :string 
  end
end
