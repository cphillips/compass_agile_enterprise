# create_table :agreement_party_roles do |t|
#   t.column  :description,   	    :string 
#   t.column  :agreement_id,     	  :integer  
#   t.column  :party_id,         	  :integer    
#   t.column  :role_type_id,     	  :integer
#   t.column  :external_identifier, :string
#   t.column  :external_id_source,  :string
#   
#   t.timestamps
# end
#
# add_index :agreement_party_roles, :agreement_id
# add_index :agreement_party_roles, :party_id
# add_index :agreement_party_roles, :role_type_id

class AgreementPartyRole < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  belongs_to  :agreement
  belongs_to  :party
  belongs_to  :role_type

end
