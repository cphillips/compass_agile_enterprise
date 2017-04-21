# create_table :unit_of_measurements do |t|
#   t.string :description
#   t.string :domain
#   t.string :internal_identifier
#   t.string :comments
#   t.string :external_identifier
#   t.string :external_id_source
#
#   t.integer :lft
#   t.integer :rgt
#   t.integer :parent_id
#
#   t.timestamps
# end
#
# add_index :unit_of_measurements, :lft
# add_index :unit_of_measurements, :rgt
# add_index :unit_of_measurements, :parent_id

class UnitOfMeasurement < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  acts_as_nested_set
  include ErpTechSvcs::Utils::DefaultNestedSetMethods

  tracks_created_by_updated_by

  has_many :party_unit_of_measurements

  class << self
    # scope by dba organization
    #
    # @param dba_organization [Party, Array] dba organization to scope by or Array of dba organizations to
    # scope by
    #
    # @return [ActiveRecord::Relation]
    def scope_by_dba_organization(dba_organization)
      joins(:party_unit_of_measurements)
      .where({party_unit_of_measurements: {party_id: dba_organization}})
    end
  end

  def set_dba_organization(dba_organization)
    self.party_unit_of_measurements.create(party: dba_organization)
  end
  alias :set_tenant :set_dba_organization

  def to_data_hash
    to_hash(only: [:id,
                   :description,
                   :domain,
                   :internal_identifier,
                   :comments,
                   :external_identifier,
                   :external_id_source,
                   :created_at,
                   :updated_at])
  end

end
