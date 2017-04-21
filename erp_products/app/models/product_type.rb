# create_table :product_types do |t|
#   #these columns are required to support the behavior of the plugin 'better_nested_set'
#   #ALL products have the ability to act as packages in a nested set-type structure
#   #
#   #The package behavior is treated differently from other product_relationship behavior
#   #which is implemented using a standard relationship structure.
#   #
#   #This is to allow quick construction of highly nested product types.
#   t.column    :parent_id,              :integer
#   t.column    :lft,                    :integer
#   t.column    :rgt,                    :integer
#
#   #custom columns go here
#   t.column  :description,              :string
#   t.column  :product_type_record_id,   :integer
#   t.column  :product_type_record_type, :string
#   t.column  :external_identifier,      :string
#   t.column  :internal_identifier,      :string
#   t.column  :external_id_source,       :string
#   t.column  :default_image_url,        :string
#   t.column  :list_view_image_id,       :integer
#   t.column  :length,                   :decimal
#   t.column  :width,                    :decimal
#   t.column  :height,                   :decimal
#   t.column  :weight,                   :decimal
#   t.column  :cylindrical,              :boolean
#   t.column  :taxable                   :boolean
#   t.column  :available_on_web          :boolean
#
#   t.references :unit_of_measurement
#   t.references :revenue_gl_account
#   t.references :expense_gl_account
#
#   t.timestamps
# end
#
# add_index :product_types, :revenue_gl_account_id, name: 'product_types_rev_gl_acct_idx'
# add_index :product_types, :expense_gl_account_id, name: 'product_types_exp_gl_acct_idx'

class ProductType < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  acts_as_nested_set
  include ErpTechSvcs::Utils::DefaultNestedSetMethods
  acts_as_taggable

  tracks_created_by_updated_by
  has_file_assets
  is_describable

  belongs_to :product_type_record, polymorphic: true
  belongs_to :unit_of_measurement

  belongs_to :revenue_gl_account, class_name: 'BizTxnAcctRoot', foreign_key: 'revenue_gl_account_id'
  belongs_to :expense_gl_account, class_name: 'BizTxnAcctRoot', foreign_key: 'expense_gl_account_id'

  has_one :product_instance
  has_many :product_type_pty_roles, dependent: :destroy
  has_many :simple_product_offers, dependent: :destroy
  has_many :product_feature_applicabilities, dependent: :destroy, as: :feature_of_record
  has_one :category_classification, as: :classification, dependent: :destroy
  has_one :category, through: :category_classification

  has_many :product_option_applicabilities, dependent: :destroy, as: :optioned_record

  validates :internal_identifier, :uniqueness => true, :allow_nil => true

  class << self
    # Filter records
    #
    # @param filters [Hash] a hash of filters to be applied,
    # @param statement [ActiveRecord::Relation] the query being built
    # @return [ActiveRecord::Relation] the query being built
    def apply_filters(filters, statement=nil)
      unless statement
        statement = ProductType
      end

      if filters[:id]
        statement = statement.where(id: filters[:id])
      end

      if filters[:category_id]
        statement = statement.joins("inner join category_classifications on category_classifications.classification_type = 'ProductType'
                         and category_classifications.classification_id = product_types.id")
        statement = statement.where('category_classifications.category_id' => filters[:category_id])
      end

      if filters[:party]
        if filters[:party].is_a? Hash
          statement = statement.scope_by_party(filters[:party][:id], {role_types: filters[:party][:role_types].split(',')})
        else
          statement = statement.scope_by_party(filters[:party])
        end
      end

      if filters and filters[:keyword]
        product_types_tbl = self.arel_table
        descriptive_assets_tbl = DescriptiveAsset.arel_table

        join_stmt = "LEFT OUTER JOIN descriptive_assets ON descriptive_assets.described_record_id = product_types.id AND descriptive_assets.described_record_type = 'ProductType' AND #{descriptive_assets_tbl[:description].matches('%' + filters[:keyword] + '%').to_sql}"

        statement = statement.joins(join_stmt).where(product_types_tbl[:description].matches('%' + filters[:keyword] + '%'))
      end

      if filters[:available_on_web]
        statement = statement.where(available_on_web: true)
      end

      if filters[:not_available_on_web]
        statement = statement.where(available_on_web: false)
      end

      statement
    end

    #
    # scoping helpers
    #

    # scope by dba organization
    #
    # @param dba_organization [Party] dba organization to scope by
    #
    # @return [ActiveRecord::Relation]
    def scope_by_dba_organization(dba_organization)
      scope_by_party(dba_organization, {role_types: [RoleType.iid('dba_org')]})
    end

    # scope by party
    #
    # @param party [Integer | Party | Array] either a id of Party record, a Party record, an array of Party records
    # or an array of Party ids
    # @param options [Hash] options to apply to this scope
    # @option options [Array] :role_types role types to include in the scope
    #
    # @return [ActiveRecord::Relation]
    def scope_by_party(party, options={})
      statement = joins(:product_type_pty_roles).where("product_type_pty_roles.party_id" => party).uniq

      if options[:role_types]
        statement = statement.where("product_type_pty_roles.role_type_id" => RoleType.find_child_role_types(options[:role_types]))
      end

      statement
    end
  end

  # add party with passed role to this ProductType
  #
  # @param party [Party] party to add
  # @param role_type [RoleType] role type to use in the association
  # @return [ProductTypePtyRole] newly created relationship
  def add_party_with_role(party, role_type)
    ProductTypePtyRole.create(
      product_type: self,
      party: party,
      role_type: role_type
    )
  end

  def taxable?
    self.taxable
  end

  def prod_type_relns_to
    ProdTypeReln.where('prod_type_id_to = ?', id)
  end

  def prod_type_relns_from
    ProdTypeReln.where('prod_type_id_from = ?', id)
  end

  def to_label
    "#{description}"
  end

  def to_s
    "#{description}"
  end

  def self.count_by_status(product_type, prod_availability_status_type)
    ProductInstance.count("product_type_id = #{product_type.id} and prod_availability_status_type_id = #{prod_availability_status_type.id}")
  end

  def images_path
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => Rails.application.config.erp_tech_svcs.file_storage)
    File.join(file_support.root, Rails.application.config.erp_tech_svcs.file_assets_location, 'products', 'images', "#{self.description.underscore}_#{self.id}")
  end

  def to_data_hash
    data = to_hash(only: [
                     :id,
                     :description,
                     :internal_identifier,
                     :sku,
                     :comment,
                     :created_at,
                     :updated_at
                   ],
                   offer_list_description: find_description_by_view_type('list_description').try(:description),
                   offer_short_description: find_description_by_view_type('short_description').try(:description),
                   offer_long_description: find_description_by_view_type('long_description').try(:description),
                   unit_of_measurement: try(:unit_of_measurement).try(:to_data_hash),
                   price: try(:get_current_simple_plan).try(:money_amount),
                   cost: custom_fields['cost'],
                   revenue_gl_account: try(:revenue_gl_account).try(:to_data_hash),
                   expense_gl_account: try(:expense_gl_account).try(:to_data_hash),
                   img_url: images.first.try(:fully_qualified_url),
                   vendor: find_party_by_role(RoleType.iid('vendor')).try(:description),
                   images: [])

    if self.images.empty?
      data[:images] << "#{ErpTechSvcs::Config.file_protocol}://#{ErpTechSvcs::Config.installation_domain}/#{Rails.configuration.assets.prefix}/place_holder.jpeg"
    else
      self.images.each do |image|
        data[:images] << image.fully_qualified_url
      end
    end

    data[:options] = product_option_applicabilities.collect{|item| item.to_data_hash({include_options: true})}

    data
  end

  def to_display_hash
    {
      id: id,
      description: description,
      offer_list_description: find_descriptions_by_view_type('list_description').first.try(:description),
      offer_short_description: find_descriptions_by_view_type('short_description').first.try(:description),
      offer_long_description: find_descriptions_by_view_type('long_description').first.try(:description),
      offer_base_price: get_current_simple_amount_with_currency,
      images: images.pluck(:id)
    }
  end

  def to_mobile_hash
    to_data_hash
  end

  # Get dba_organzation info eventually going to be tenant
  def dba_organization
    find_party_by_role(RoleType.dba_org)
  end
  alias :tenant :dba_organization

  def parent_dba_organizations(dba_orgs=[])
    ProductTypePtyRole.
      where('product_type_id = ?', id).
    where('role_type_id' => RoleType.iid('dba_org').id).each do |prod_party_reln|

      dba_orgs.push(prod_party_reln.party)
      prod_party_reln.party.parent_dba_organizations(dba_orgs)
    end

    dba_orgs.uniq
  end

  def add_party_with_role(party, role_type)
    if role_type.is_a?(String)
      role_type = RoleType.iid(role_type)
    end

    ProductTypePtyRole.create(party: party, role_type: role_type, product_type: self)
  end

  def find_party_by_role(role_types)
    unless role_types.is_a? Array
      role_types = [role_types]
    end

    role_types = RoleType.find_child_role_types(role_types)

    product_type_pty_roles.where(role_type_id: role_types).first.try(:party)
  end

  def has_dimensions?
    (cylindrical && length && width && weight) or (length && width && height && weight)
  end
end

module Arel
  class SelectManager
    def polymorphic_join(hash={polytable: nil, table: nil, model: nil, polymodel: nil, record_type_name: nil, record_id_name: nil, table_model: nil})
      # Left Outer Join with 2 possible hash argument sets:
      #   1) model (AR model), polymodel (AR model), record_type_name (symbol), record_id_name (symbol)
      #   2) polytable (arel_table), table (arel_table), record_type_name (symbol), record_id_name (symbol), table_model (string)

      if hash[:model] && hash[:polymodel]
        self.join(hash[:polymodel].arel_table, Arel::Nodes::OuterJoin).on(hash[:polymodel].arel_table[hash[:record_id_name]].eq(hash[:model].arel_table[:id]).and(hash[:polymodel].arel_table[hash[:record_type_name]].eq(hash[:model].to_s)))
      elsif hash[:polytable] && hash[:record_type_name]
        self.join(hash[:polytable], Arel::Nodes::OuterJoin).on(hash[:polytable][hash[:record_id_name]].eq(hash[:table][:id]).and(hash[:polytable][hash[:record_type_name]].eq(hash[:table_model])))
      else
        raise 'Invalid Args'
      end
    end
  end
end
