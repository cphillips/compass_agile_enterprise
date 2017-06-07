# create_table :agreements do |t|
#   t.column  :description,       :string
#   t.column  :agreement_type_id, :integer
#   t.column  :agreement_status,  :string
#   t.column  :product_id,        :integer
#   t.column  :agreement_date,    :date
#   t.column  :from_date,         :date
#   t.column  :thru_date,         :date
#   t.column  :external_identifier, :string
#   t.column  :external_id_source,  :string
#
#   t.timestamps
# end
#
# add_index :agreements, :agreement_type_id
# add_index :agreements, :product_id

class Agreement < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  belongs_to :agreement_type
  has_many   :agreement_items, dependent: :destroy
  has_many   :agreement_party_roles, dependent: :destroy
  has_many   :parties, :through => :agreement_party_roles
  has_many   :agreement_records, dependent: :destroy

  alias :items :agreement_items

  def agreement_relationships
    AgreementRelationship.where('agreement_id_from = ? OR agreement_id_to = ?',id,id)
  end

  def to_s
    description
  end

  def to_label
    to_s
  end

  def find_parties_by_role(role)
    self.parties.where("role_type_id = ?", role.id).all
  end

  def get_item_by_item_type_internal_identifier(item_type_internal_identifier)
    agreement_items.joins("join agreement_item_types on
                           agreement_item_types.id = 
                           agreement_items.agreement_item_type_id").where("agreement_item_types.internal_identifier = '#{item_type_internal_identifier}'").first
  end

  def respond_to?(m, include_private_methods = false)
    if super
      true
    else
      ((get_item_by_item_type_internal_identifier(m.to_s).nil? ? false : true))
    end
  end

  def method_missing(m, *args, &block)
    agreement_item = get_item_by_item_type_internal_identifier(m.to_s)
    (agreement_item.nil?) ? super : (return agreement_item.agreement_item_value)
  end

end
