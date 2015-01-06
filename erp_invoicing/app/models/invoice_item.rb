#### Table Definition ###########################
#  create_table :invoice_items do |t|
#    #foreign keys
#    t.references :invoice
#    t.references :invoice_item_type
#
#    #these columns support the polymporphic relationship to invoice-able items
#    t.references :invoiceable_item, :polymorphic => true
#
#    #non-key columns
#    t.integer    :item_seq_id
#    t.string     :item_description
#    t.decimal    :sales_tax, :precision => 8, :scale => 2
#    t.decimal    :quantity, :precision => 8, :scale => 2
#    t.decimal    :amount, :precision => 8, :scale => 2
#
#    t.timestamps
#  end

#  add_index :invoice_items, [:invoiceable_item_id, :invoiceable_item_type], :name => 'invoiceable_item_idx'
#  add_index :invoice_items, :invoice_id, :name => 'invoice_id_idx'
#  add_index :invoice_items, :invoice_item_type_id, :name => 'invoice_item_type_id_idx'
#################################################

class InvoiceItem < ActiveRecord::Base
  attr_protected :created_at, :updated_at

	belongs_to 	:agreement
	belongs_to	:invoice_item_type
  belongs_to  :invoiceable_item, :polymorphic => true

	#This line of code connects the invoice to a polymorphic payment application.
	#The effect of this is to allow payments to be "applied_to" invoices
  has_many    :payment_applications, :as => :payment_applied_to, :dependent => :destroy do
    def pending
      all.select{|item| item.is_pending?}
    end
    def successful
      all.select{|item| item.financial_txn.has_captured_payment?}
    end
  end

  def has_payments?(status)
    selected_payment_applications = self.get_payment_applications(status)
    !(selected_payment_applications.nil? or selected_payment_applications.empty?)
  end
  
  def get_payment_applications(status=:all)
    case status.to_sym
    when :pending
      self.payment_applications.pending
    when :successful
      self.payment_applications.successful
    when :all
      self.payment_applications
    end
  end

  def total_amount
    (self.amount * self.quantity)
  end

   def total_payments
    self.get_payment_applications(:successful).sum{|item| item.money.amount}
  end

  def balance
    self.total_amount - self.total_payments
  end

end
