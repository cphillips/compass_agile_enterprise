# create_table :agreement_items do |t|
#   t.integer  :agreement_id
#   t.integer  :agreement_item_type_id
#   t.string  :agreement_item_value
#   t.string  :description
#   t.string  :agreement_item_rule_string
#   
#   t.timestamps
# end
#
# add_index :agreement_items, :agreement_id
# add_index :agreement_items, :agreement_item_type_id

class AgreementItem < ActiveRecord::Base
  attr_protected :created_at, :updated_at

	belongs_to 	:agreement
	belongs_to	:agreement_item_type
end
