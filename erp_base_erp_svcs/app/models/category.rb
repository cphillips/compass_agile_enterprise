# unless table_exists?(:categories)
#   create_table :categories do |t|
#     t.string :description
#     t.text :long_description
#     t.string :external_identifier
#     t.datetime :from_date
#     t.datetime :to_date
#     t.string :internal_identifier
#     t.boolean :is_internal default: false
#
#     # polymorphic assns
#     t.integer :category_record_id
#     t.string :category_record_type
#
#     # nested set cols
#     t.integer :parent_id
#     t.integer :lft
#     t.integer :rgt
#
#     t.integer :tenant_id
#
#     t.timestamps
#   end
#
#   add_index :categories, [:category_record_id, :category_record_type], :name => "category_polymorphic"
#   add_index :categories, :internal_identifier, :name => 'categories_internal_identifier_idx'
#   add_index :categories, :parent_id, :name => 'categories_parent_id_idx'
#   add_index :categories, :lft, :name => 'categories_lft_idx'
#   add_index :categories, :rgt, :name => 'categories_rgt_idx'
#   add_index :categories, :tenant_id, name: 'categories_tenant_idx'
# end

class Category < ActiveRecord::Base

  is_tenantable
  acts_as_erp_type
  acts_as_nested_set
  include ErpTechSvcs::Utils::DefaultNestedSetMethods

  has_file_assets

  attr_protected :created_at, :updated_at

  validates :internal_identifier, uniqueness: {allow_nil: false}

  belongs_to :category_record, :polymorphic => true
  has_many :category_classifications, :dependent => :destroy

  class << self
    # Filter records
    #
    # @param filters [Hash] a hash of filters to be applied,
    # @param statement [ActiveRecord::Relation] the query being built
    # @return [ActiveRecord::Relation] the query being built
    def apply_filters(filters, statement=nil)
      unless statement
        statement = self
      end

      # filter by parent
      if filters[:parent]
        if filters[:parent].is_a? Fixnum || filters[:parent].is_integer?
          statement = statement.where(categories: {parent_id: filters[:parent]})
        else
          statement = statement.where(categories: {parent_id: Category.iid(filters[:parent])})
        end
      end

      if filters[:parent_id]
        statement = statement.where(categories: {parent_id: filters[:parent_id]})
      end

      # filter by query which will filter on description
      if filters[:query]
        statement = statement.where('description ilike ?', "%#{filters[:query].strip}%")
      end

      statement
    end

    # scope by dba organization
    #
    # @param dba_organization [Party] dba organization to scope by
    #
    # @return [ActiveRecord::Relation]
    def scope_by_dba_organization(dba_organization)
      by_tenant(dba_organization)
    end

    alias scope_by_dba scope_by_dba_organization

    def iid(internal_identifier)
      where("internal_identifier = ?", internal_identifier).first
    end

    def non_internal
      where('is_internal = ?', false)
    end

    def with_products(dba_organization, context={})
      category_ids_with_products = []

      self.by_tenant(dba_organization)
      .joins(:category_classifications)
      .joins("join product_types on product_types.id = category_classifications.classification_id
                and category_classifications.classification_type = 'ProductType' ").uniq.each do |category|

        category_ids_with_products.push(category.id)
        category_ids_with_products = category_ids_with_products.concat(category.ancestors.collect(&:id))

      end

      category_ids_with_products.uniq
    end
  end

  def to_data_hash(context={})
    data = to_hash(
      only: [
        :id,
        :description,
        :long_description,
        :internal_identifier,
        :created_at,
        :updated_at
      ],
      leaf: leaf?
    )

    data['image_url'] = self.images.first.try(:fully_qualified_url)

    data
  end

end
