# create_table :parties do |t|
#   t.column :description, :string
#   t.column :business_party_id, :integer
#   t.column :business_party_type, :string
#   t.column :list_view_image_id, :integer
#
#   #This field is here to provide a direct way to map CompassAE
#   #business parties to unified idenfiers in organizations if they
#   #have been implemented in an enterprise.
#   t.column :enterprise_identifier, :string
#   t.timestamps
# end
# add_index :parties, [:business_party_id, :business_party_type], :name => "besi_1"

class Party < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  has_notes
  has_contacts
  tracks_created_by_updated_by

  has_many :created_notes, :class_name => 'Note', :foreign_key => 'created_by_party_id'
  belongs_to :business_party, :polymorphic => true

  has_many :entity_party_roles, dependent: :destroy
  has_many :compass_ae_instance_party_roles, dependent: :destroy

  has_many :party_roles, :dependent => :destroy #role_types
  has_many :role_types, :through => :party_roles

  after_destroy :destroy_business_party, :destroy_party_relationships

  attr_reader :relationships
  attr_writer :create_relationship

  class << self
    # Filter records
    #
    # @param filters [Hash] a hash of filters to be applied,
    # @param statement [ActiveRecord::Relation] the query being built
    # @return [ActiveRecord::Relation] the query being built
    def apply_filters(filters, statement=nil)
      statement = statement || Party

      if filters[:query]
        parties_tbl = Party.arel_table

        where_clause = nil
        # if the query has commas split on the commas and treat them as separate search terms
        filters[:query].split(',').each do |query_part|
          if where_clause.nil?
            where_clause = parties_tbl[:description].matches(query_part.strip + '%')
            .or(Party.arel_table[:enterprise_identifier].matches(query_part.strip + '%'))
          else
            where_clause = where_clause.or(parties_tbl[:description].matches(query_part.strip + '%'))
            .or(Party.arel_table[:enterprise_identifier].matches(query_part.strip + '%'))
          end
        end

        statement = statement.where(where_clause)
      end

      if filters[:role_types]
        if filters[:include_child_roles]
          role_types = RoleType.find_child_role_types(filters[:role_types].split(',')).collect{|role_type| role_type.internal_identifier}
        else
          role_types = filters[:role_types].split(',')
        end

        statement = statement.joins(party_roles: :role_type).where('role_types.internal_identifier' => role_types)
      end

      if filters[:enterprise_identifier]
        statement = statement.where(Party.arel_table[:enterprise_identifier].matches("#{filters[:enterprise_identifier]}%"))
      end

      if filters[:email_address]
        statement = statement.joins("join contacts on contacts.contact_record_id = parties.id
                                           and contacts.contact_record_type = 'Party'")
        .joins("join email_addresses on contacts.contact_mechanism_type =
                              'EmailAddress' and contacts.contact_mechanism_id = email_addresses.id")

        statement = statement.where(::EmailAddress.arel_table[:email_address].eq("#{filters[:email_address]}"))
      end

      if filters[:phone_number]
        statement = statement.joins("join contacts on contacts.contact_record_id = parties.id
                                           and contacts.contact_record_type = 'Party'")
        .joins("join phone_numbers on contacts.contact_mechanism_type =
                              'PhoneNumber' and contacts.contact_mechanism_id = phone_numbers.id")

        statement = statement.where(::PhoneNumber.arel_table[:phone_number].eq("#{filters[:phone_number]}"))
      end

      if filters[:postal_address]
        statement = statement.joins("join contacts on contacts.contact_record_id = parties.id
                                           and contacts.contact_record_type = 'Party'")
        .joins("join postal_addresses on contacts.contact_mechanism_type = 'PostalAddress'
          and contacts.contact_mechanism_id = postal_addresses.id")

        where = nil
        filters[:postal_address].each do |key, value|
          if where
            where = where.and(::PostalAddress.arel_table[key].eq("#{value}"))
          else
            where = ::PostalAddress.arel_table[key].eq("#{value}")
          end
        end

        statement = statement.where(where)
      end

      statement
    end

    # scope by dba organization
    #
    # @param dba_organization [Party, Array] dba organization to scope by or Array of dba organizations to
    # scope by
    #
    # @return [ActiveRecord::Relation]
    def scope_by_dba_organization(dba_organization)
      joins("inner join party_relationships on party_relationships.role_type_id_to ='#{RoleType.iid('dba_org').id}'
             and party_relationships.party_id_from = parties.id")
      .where({party_relationships: {party_id_to: dba_organization}})
    end

    alias :by_tenant :scope_by_dba_organization

    # Scopes parties by passed role types
    #
    # @param role_types [Array, RoleType] Array of RoleTypes to scope by
    def with_role_types(role_types)
      joins('inner join party_roles on party_roles.party_id = parties.id').where('party_roles.role_type_id' => role_types)
    end

  end

  # helper method to get dba_organization related to this party
  #
  # @return [Party] DBA Organization
  def dba_organization
    find_related_parties_with_role('dba_org').first
  end
  alias :tenant :dba_organization

  # if dba_org exists, delete it and replace it
  # if it doesn't exist, create it
  #
  # @param party party of the dba org for this party
  def set_dba_org(to_party_id, reln_type=nil,  description="DBA Organization")
    if to_party_id.is_a? Party
      to_party_id = to_party_id.id
    end

    if dba_organization
      dba_party_relationship = find_relationship_by_role_type('dba_org')
      unless dba_party_relationship.nil?
        dba_party_relationship.delete
      end
    end

    reln_type ||= RelationshipType.iid('employee_to_dba_org')

    create_relationship(description, to_party_id, reln_type)
  end

  alias :set_tenant! :set_dba_org

  def find_relationship_by_role_type(role_type_iid)
    PartyRelationship.includes(:relationship_type).
      where('party_id_from = ? or party_id_to = ?', id, id).
      where('role_type_id_to' => RoleType.iid(role_type_iid)).first
  end

  # Get any child DBA Organizations related this party
  #
  # @param dba_orgs [Array] Array of current DBA Organizations to add to
  # @return [Array] Child DBA Organizations
  def child_dba_organizations(dba_orgs=[])
    dba_org = RoleType.iid('dba_org')

    PartyRelationship.joins('inner join parties on parties.id = party_relationships.party_id_from')
    .joins('inner join party_roles on party_roles.party_id = party_relationships.party_id_from')
    .where('party_id_to' => self.id)
    .where('party_relationships.role_type_id_to' => dba_org)
    .where('party_roles.role_type_id' => dba_org).each do |party_reln|

      dba_orgs.push(party_reln.from_party)
      if !dba_orgs.collect(&:id).include? party_reln.from_party.id
        party_reln.from_party.child_dba_organizations(dba_orgs)
      end

    end

    dba_orgs.uniq
  end

  # Get all parties that have a relationship to this party. If deep is passed then of those parties do the same
  # all the way down the relationship chain
  #
  # @param parties [Array] Array of currently found related parties
  # @return [Array] Array of related parties
  def parties_in_relationships(parties=[], deep=false)
    PartyRelationship.where('party_id_to' => self.id).each do |party_reln|

      parties.push(party_reln.from_party) unless parties.include?(party_reln.from_party)
      if deep and !parties.collect(&:id).include? party_reln.from_party.id
        party_reln.from_party.parties_in_relationships(parties, deep)
      else
        parties
      end

    end

    parties.uniq
  end

  # Get any parent DBA Organizations related this party
  #
  # @param dba_orgs [Array] Array of current DBA Organizations to add to
  # @return [Array] Parent DBA Organizations
  def parent_dba_organizations(dba_orgs=[])
    PartyRelationship.
      where('party_id_from = ?', id).
    where('role_type_id_to' => RoleType.iid('dba_org')).each do |party_reln|

      dba_orgs.push(party_reln.to_party)
      party_reln.to_party.parent_dba_organizations(dba_orgs)
    end

    dba_orgs.uniq
  end


  # Gathers all party relationships that contain this particular party id
  # in either the from or to side of the relationship.
  def relationships
    @relationships ||= PartyRelationship.where('party_id_from = ? or party_id_to = ?', id, id)
  end

  def to_relationships
    @relationships ||= PartyRelationship.where('party_id_to = ?', id)
  end

  def from_relationships
    @relationships ||= PartyRelationship.where('party_id_from = ?', id)
  end

  def find_related_parties_with_role(role_type_iid)
    Party.joins(:party_roles).joins("inner join party_relationships on (party_id_from = parties.id or party_id_to = parties.id)")
    .where(PartyRole.arel_table[:role_type_id].eq(RoleType.iid(role_type_iid).id))
    .where("(party_id_from = #{id} or party_id_to = #{id})")
    .where(Party.arel_table[:id].not_eq(id))
  end

  def find_relationships_by_type(relationship_type_iid)
    PartyRelationship.includes(:relationship_type).
      where('party_id_from = ? or party_id_to = ?', id, id).
      where('relationship_types.internal_identifier' => relationship_type_iid.to_s)
  end

  # Creates a new PartyRelationship for this particular
  # party instance.
  def create_relationship(description, to_party_id, reln_type)
    PartyRelationship.create(:description => description,
                             :relationship_type => reln_type,
                             :party_id_from => id,
                             :from_role => reln_type.valid_from_role,
                             :party_id_to => to_party_id,
                             :to_role => reln_type.valid_to_role)
  end

  # Callbacks
  def destroy_business_party
    if self.business_party
      self.business_party.destroy
    end
  end

  def destroy_party_relationships
    PartyRelationship.destroy_all("party_id_from = #{id} or party_id_to = #{id}")
  end

  def add_role_type(role)
    role = role.is_a?(RoleType) ? role : RoleType.iid(role)

    PartyRole.create(party: self, role_type: role)
  end

  def has_role_type?(*passed_roles)
    result = false
    passed_roles.flatten!
    passed_roles.each do |role|
      role_iid = role.is_a?(RoleType) ? role.internal_identifier : role.to_s

      PartyRole.where(party_id: self.id).each do |party_role|
        result = true if (party_role.role_type.internal_identifier == role_iid)
        break if result
      end

    end
    result
  end

  # Alias for to_s
  def to_label
    to_s
  end

  def to_s
    "#{description}"
  end

  # convert party record to hash of data
  #
  # @param opts [Hash] Options for converting to data hash
  # @option opts [Boolean] :include_email true to include email address
  # @option opts [String] :email_purposes comma sperated list of contact purposes of emails to include
  # @option opts [Boolean] :include_phone_number true to include phone numbers
  # @option opts [String] :phone_number_purposes comma sperated list of contact purposes of phone numbers to include
  # @option opts [Boolean] :include_postal_address true to include postal addresses
  # @option opts [String] :postal_address_purposes comma sperated list of contact purposes of postal addresses to include
  def to_data_hash(opts={})
    data = to_hash(only: [
                     :id,
                     :description,
                     :created_at,
                     :enterprise_identifier,
                     :updated_at
                   ],
                   business_party_type: business_party.class.name
                   )

    # get business party data
    if business_party
      if business_party.is_a?(Individual)
        data.merge!({
                      first_name: business_party.current_first_name,
                      last_name: business_party.current_last_name,
                      middle_name: business_party.current_middle_name,
                      gender: business_party.gender
        })
      else
        data.merge!({
                      tax_id_number: business_party.tax_id_number
        })
      end
    end

    if opts[:include_email]
      if opts[:email_purposes].present?
        contact_purposes = opts[:email_purposes].split(',')
        data[:email_addresses] = email_addresses_to_hash(contact_purposes)
      else
        data[:email_addresses] = email_addresses_to_hash
      end
    end

    if opts[:include_phone_number]
      if opts[:phone_number_purposes].present?
        contact_purposes = opts[:phone_number_purposes].split(',')
        data[:phone_numbers] = phone_numbers_to_hash(contact_purposes)
      else
        data[:phone_numbers] = phone_numbers_to_hash
      end
    end

    if opts[:include_postal_address]
      if opts[:postal_address_purposes].present?
        contact_purposes = opts[:postal_address_purposes].split(',')
        data[:postal_addresses] = postal_addresses_to_hash(contact_purposes)
      else
        data[:postal_addresses] = postal_addresses_to_hash
      end
    end

    data
  end

end
