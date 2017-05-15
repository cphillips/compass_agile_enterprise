# create_table :agreement_reln_types do |t|
# 	t.column  	:parent_id,    :integer
# 	t.column  	:lft,          :integer
# 	t.column  	:rgt,          :integer
#
#   #custom columns go here        
# 	t.column  :valid_from_role_type_id,   :integer
# 	t.column  :valid_to_role_type_id,     :integer
# 	t.column  :name,                      :string  
# 	t.column  :description,               :string
#   t.column  :internal_identifier, 	    :string
#   t.column  :external_identifier, 	    :string
#   t.column  :external_id_source, 	      :string
#     
# 	t.timestamps
# end
#
# add_index :agreement_reln_types, :parent_id
# add_index :agreement_reln_types, :valid_from_role_type_id
# add_index :agreement_reln_types, :valid_to_role_type_id

class AgreementRelnType < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  acts_as_nested_set
  include ErpTechSvcs::Utils::DefaultNestedSetMethods
  
  belongs_to :valid_from_role, :class_name => "AgreementRoleType", :foreign_key => "valid_from_role_type_id"
  belongs_to :valid_to_role,   :class_name => "AgreementRoleType", :foreign_key => "valid_to_role_type_id"
end
