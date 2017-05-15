# create_table :agreement_role_types do |t|
#
# 	t.column  	:parent_id,    			:integer
# 	t.column  	:lft,          			:integer
# 	t.column  	:rgt,          			:integer
#
#   #custom columns go here   
# 	t.column  :description,         :string
# 	t.column  :comments,            :string
#   t.column  :internal_identifier, :string
#   t.column  :external_identifier, :string
#   t.column  :external_id_source, 	:string
#     
#   t.timestamps
# end
#
# add_index :agreement_role_types, :parent_id
# add_index :agreement_role_types, :lft
# add_index :agreement_role_types, :rgt

class AgreementRoleType < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  acts_as_nested_set
  include ErpTechSvcs::Utils::DefaultNestedSetMethods
end
