# unless table_exists?(:groups)
#   create_table :groups do |t|
#     t.column :description, :string
#     t.timestamps
#   end
# end

# Security Group
class Group < ActiveRecord::Base
  has_capability_accessors

  after_create  :create_party
  after_save    :save_party
  after_destroy :destroy_party_relationships, :destroy_party

  has_one :party, :as => :business_party
  has_one :group_type

  attr_accessible :description, :group_type_id
  validates_uniqueness_of :description, :case_sensitive => false

  def self.add_with_type(description, group_type)
    Group.create(:description => description, :group_type_id => group_type.id)
  end

  def self.by_group_type(group_type)
    Group.where('group_type_id = ?', group_type.id)
  end


  def self.add(description)
    Group.create(:description => description)
  end

  # roles this group does NOT have
  def roles_not
    party.roles_not
  end

  # roles this group has
  def roles
    party.security_roles
  end

  def has_role?(role)
    role = role.is_a?(SecurityRole) ? role : SecurityRole.find_by_internal_identifier(role.to_s)
    roles.include?(role)
  end

  def add_role(role)
    party.add_role(role)
  end

  def remove_role(role)
    party.remove_role(role)
  end

  def remove_all_roles
    party.remove_all_roles
  end

  def create_party
    pty = Party.new
    pty.description = self.description
    pty.business_party = self

    pty.save
    self.save
  end

  def save_party
    self.party.description = self.description
    self.party.save
  end

  def destroy_party
    if self.party
      self.party.destroy
    end
  end

  def destroy_party_relationships
    party_relationships.destroy_all
  end

  # group lives on TO side of relationship
  def party_relationships
    PartyRelationship.where(:party_id_to => self.party.id)
  end

  def members
    Party.joins("JOIN #{group_member_join}")
  end

  # get users in this group
  def users
    User.joins(:party).joins("JOIN #{group_member_join}")
  end

  # get users not in this group
  def users_not
    User.joins(:party).joins("LEFT JOIN #{group_member_join}").where("party_relationships.id IS NULL")
  end

  # add user to group
  def add_user(user)
    add_party(user.party)
  end

  # remove user from group
  def remove_user(user)
    remove_party(user.party)
  end

  def get_relationship(a_party)
    role_type = RoleType.find_by_internal_identifier('group')
    PartyRelationship.where(:party_id_to => self.party.id, :party_id_from => a_party.id, :role_type_id_to => role_type.id)
  end

  # add party to group
  # group lives on TO side of relationship
  def add_party(a_party)
    # check and see if party is already a member of this group
    rel = get_relationship(a_party).first
    unless rel.nil?
      # if so, return relationship
      return rel
    else
      # if not then build party_relationship
      rt = RelationshipType.find_by_internal_identifier('group_membership')
      pr = PartyRelationship.new
      pr.description = rt.description
      pr.relationship_type = rt
      pr.from_role = RoleType.find_by_internal_identifier('group_member')
      pr.to_role = RoleType.find_by_internal_identifier('group')
      pr.from_party = a_party
      pr.to_party = self.party
      pr.save
      return pr
    end
  end

  # remove party from group
  # group lives on TO side of relationship
  def remove_party(a_party)
    begin
      get_relationship(a_party).first.destroy
    rescue => e
      Rails.logger.error e.message
      return nil
    end
  end

  def role_class_capabilities
    scope_type = ScopeType.find_by_internal_identifier('class')
    Capability.includes(:capability_type).joins(:capability_type).joins(:capability_accessors).
      where(:capability_accessors => { :capability_accessor_record_type => "SecurityRole" }).
      where("capability_accessor_record_id IN (#{roles.select('security_roles.id').to_sql})").
      where(:scope_type_id => scope_type.id)
  end

  def all_class_capabilities
    scope_type = ScopeType.find_by_internal_identifier('class')
    Capability.includes(:capability_type).joins(:capability_type).joins(:capability_accessors).
    where("(capability_accessors.capability_accessor_record_type = 'Group' AND
                  capability_accessor_record_id = (#{self.id})) OR
                 (capability_accessors.capability_accessor_record_type = 'SecurityRole' AND
                  capability_accessor_record_id IN (#{roles.select('security_roles.id').to_sql}))").
      where(:scope_type_id => scope_type.id)
  end

  def all_uniq_class_capabilities
    all_class_capabilities.all.uniq
  end

  def class_capabilities_to_hash
    all_uniq_class_capabilities.map {|capability|
      { :capability_type_iid => capability.capability_type.description,
        :capability_resource_type => capability.capability_resource_type
        }
    }.compact
  end

  def to_data_hash
    self.to_hash(only: [:id, :description, :created_at, :updated_at])
  end

  protected

  def group_member_join
    role_type = RoleType.find_by_internal_identifier('group_member')
    "party_relationships ON party_id_from = #{self.party.id} AND party_id_to = parties.id AND role_type_id_from=#{role_type.id}"
  end

end
