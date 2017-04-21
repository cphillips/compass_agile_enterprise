# create_table :inventory_entries do |t|
#   t.column :description, :string
#   t.column :inventory_entry_record_id, :integer
#   t.column :inventory_entry_record_type, :string
#   t.column :external_identifier, :string
#   t.column :external_id_source, :string
#   t.column :product_type_id, :integer
#   t.column :number_available, :integer
#   t.string :sku
#   t.integer :number_sold
#   t.references :unit_of_measurement
#   t.integer :number_in_stock
#
#   t.integer :tenant_id
#
#   t.timestamps
# end
#
# add_index :inventory_entries, :unit_of_measurement_id, :name => 'inv_entry_uom_idx'
# add_index :inventory_entries, [:inventory_entry_record_id, :inventory_entry_record_type], :name => "bii_1"
# add_index :inventory_entries, :product_type_id

class InventoryEntry < ActiveRecord::Base
  is_tenantable

  attr_protected :created_at, :updated_at

  has_party_roles

  belongs_to :inventory_entry_record, :polymorphic => true, dependent: :destroy
  belongs_to :product_type
  has_one :classification, :as => :classification, :class_name => 'CategoryClassification', dependent: :destroy
  has_many :prod_instance_inv_entries, dependent: :destroy
  has_many :product_instances, :through => :prod_instance_inv_entries do
    def available
      includes([:prod_availability_status_type]).where('prod_availability_status_types.internal_identifier = ?', 'available')
    end

    def sold
      includes([:prod_availability_status_type]).where('prod_availability_status_types.internal_identifier = ?', 'sold')
    end
  end
  has_many :inventory_entry_locations, dependent: :destroy
  has_many :facilities, :through => :inventory_entry_locations
  belongs_to :unit_of_measurement
  has_many :order_line_items, dependent: :destroy
  has_many :inventory_txns, dependent: :destroy

  alias_method :storage_facilities, :facilities

  delegate :description, :sku, :unit_of_measurement, to: :product_type, prefix: true
  delegate :revenue_gl_account, :expense_gl_account, :taxable?, to: :product_type

  after_destroy :remove_inv_entry_relns

  class << self
    # Filter records
    #
    # @param filters [Hash] a hash of filters to be applied,
    # @param statement [ActiveRecord::Relation] the query being built
    # @return [ActiveRecord::Relation] the query being built
    def apply_filters(filters, statement=nil)
      unless statement
        statement = InventoryEntry
      end

      if filters[:id]
        statement = statement.where(id: filters[:id])
      end

      if filters and filters[:keyword]
        statement = statement.where(InventoryEntry.arel_table[:description].matches('%' + filters[:keyword] + '%'))
      end

      statement
    end
  end

  def current_location
    self.inventory_entry_locations
  end

  def current_storage_facility
    unless inventory_entry_locations.empty?
      inventory_entry_locations.last.facility
    end
  end

  def current_storage_facility=(facility)
    location = InventoryEntryLocation.new
    location.facility = facility
    location.inventory_entry = self
    location.save
  end

  def current_storage_facility_id=(facility_id)
    location = InventoryEntryLocation.new
    location.facility_id = facility_id
    location.inventory_entry = self
    location.save
  end

  def get_sku
    if self.sku.blank? and self.product_type
      self.product_type_sku
    else
      self.sku
    end
  end

  def get_uom
    if self.unit_of_measurement.nil? and self.product_type
      self.product_type_unit_of_measurement
    else
      self.unit_of_measurement
    end
  end

  def to_label
    "#{description}"
  end

  def to_data_hash
    data = to_hash(only: [
                     :id,
                     :description,
                     :number_available,
                     :number_in_stock,
                     :created_at,
                     :updated_at
                   ],
                   sku: get_sku,
                   product_type: try(:product_type).try(:to_data_hash))

    if get_uom
      data[:unit_of_measurement] = get_uom.to_data_hash
    else
      data[:unit_of_measurement] = nil
    end

    if current_storage_facility
      data[:inventory_storage_facility] = current_storage_facility.to_data_hash
    else
      data[:inventory_storage_facility] = nil
    end

    data
  end

  # callbacks

  # Remove any InvEntryReln after this record is destroyed
  #
  def remove_inv_entry_relns
    InvEntryReln.where(InvEntryReln.arel_table[:inv_entry_id_from].eq(self.id).or(InvEntryReln.arel_table[:inv_entry_id_from].eq(self.id))).destroy_all
  end

end
