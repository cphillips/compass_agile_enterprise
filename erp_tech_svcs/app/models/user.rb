# create_table :users do |t|
#   t.string :username
#   t.string :email
#   t.references :party
#   t.string :type
#   t.string :salt, :default => nil
#   t.string :crypted_password, :default => nil
#
#   #activity logging
#   t.datetime :last_login_at, :default => nil
#   t.datetime :last_logout_at, :default => nil
#   t.datetime :last_activity_at, :default => nil
#
#   #brute force protection
#   t.integer :failed_logins_count, :default => 0
#   t.datetime :lock_expires_at, :default => nil
#
#   #remember me
#   t.string :remember_me_token, :default => nil
#   t.datetime :remember_me_token_expires_at, :default => nil
#
#   #reset password
#   t.string :reset_password_token, :default => nil
#   t.datetime :reset_password_token_expires_at, :default => nil
#   t.datetime :reset_password_email_sent_at, :default => nil
#
#   #user activation
#   t.string :activation_state, :default => nil
#   t.string :activation_token, :default => nil
#   t.datetime :activation_token_expires_at, :default => nil
#
#   t.string :security_question_1
#   t.string :security_answer_1
#   t.string :security_question_2
#   t.string :security_answer_2
#
#   t.string :unlock_token, :default => nil
#   t.string :last_login_from_ip_address, :default => nil
#
#   t.string :auth_token
#   t.datetime :auth_token_expires_at
#
#   t.string :time_zone
#
#   t.timestamps
# end
#
# add_index :users, :email, :unique => true
# add_index :users, :username, :unique => true
# add_index :users, [:last_logout_at, :last_activity_at], :name => 'activity_idx'
# add_index :users, :remember_me_token
# add_index :users, :reset_password_token
# add_index :users, :activation_token
# add_index :users, :party_id, :name => 'users_party_id_idx'

class User < ActiveRecord::Base
  include ErpTechSvcs::Utils::CompassAccessNegotiator
  include ActiveModel::Validations

  attr_accessor :password_validator, :skip_activation_email

  belongs_to :party
  has_many :auth_tokens

  attr_accessible :email, :password, :password_confirmation

  authenticates_with_sorcery!

  attr_protected :created_at, :updated_at

  has_capability_accessors

  #password validations
  validates_confirmation_of :password, :message => "should match confirmation", :if => :password
  validates :password, :presence => true, :password_strength => true, :if => :password

  #email validations
  validates :email, :presence => {:message => 'cannot be blank'}, :uniqueness => {:case_sensitive => false,
                                                                                  message: "In use by another user"}

  validates_format_of :email, :with => /\b[A-Z0-9._%a-z\-]+@(?:[A-Z0-9a-z\-]+\.)+[A-Za-z]{2,4}\z/

  #username validations
  validates :username, :presence => {:message => 'cannot be blank'}, :uniqueness => {:case_sensitive => false,
                                                                                     message: "In use by another user"}

  validate :email_cannot_match_username_of_other_user

  class << self

    # Filter records
    #
    # @param filters [Hash] a hash of filters to be applied,
    # @param statement [ActiveRecord::Relation] the query being built
    # @return [ActiveRecord::Relation] the query being built
    def apply_filters(filters, statement=self)

      if filters[:username]
        statement = statement.where('username like ? or email like ?', "%#{filters[:username]}%", "%#{filters[:username]}%")
      end

      if filters[:role_types]
        role_types = RoleType.find_child_role_types(filters[:role_types].split(',')).collect{|role_type| role_type.internal_identifier}.uniq

        statement = statement.joins(party: {party_roles: :role_type}).where(role_types: {internal_identifier: role_types})
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
      joins(:party).joins("inner join party_relationships on party_relationships.role_type_id_to ='#{RoleType.iid('dba_org').id}'
             and party_relationships.party_id_from = parties.id")
      .where({party_relationships: {party_id_to: dba_organization}})
    end

    alias scope_by_dba scope_by_dba_organization

    # Find or create a new User
    #
    # @param  options [Hash] Options when creating this party
    # @option options [String] :username Username for new User
    # @option options [String] :email Email for new User
    # @option options [String] :password Password for new User
    # @option options [String] :first_name First Name for new User
    # @option options [String] :last_name Last Name for new User
    # @option options [Array] :party_roles Party roles to add to the User
    # @option options [Array] :security_roles Security Roles to add to the User
    # @option options [Array] :applications Applications to add to the User
    # @option options [Party] :tenant Tenant to set for the User
    # @option options [RelationshipType] :tenant_reln_type RelationshipType to use for the Tenant relationship
    #
    # @raise [ExceptionClass] Username is required
    # @raise [ExceptionClass] Email is required
    # @raise [ExceptionClass] Password is required
    # @raise [ExceptionClass] First Name is required
    # @raise [ExceptionClass] Last Name is required
    #
    # @return [User] the found or newly created user
    def find_or_create(options={})
      raise 'Username is required' unless options[:username]
      raise 'Email is required' unless options[:email]
      raise 'Password is required' unless options[:password]
      raise 'First Name is required' unless options[:first_name]
      raise 'Last Name is required' unless options[:last_name]
      raise 'Tenant is required' unless options[:tenant]

      user = User.where('username = ?', options[:username]).first

      unless user
        user = create(username: options[:username], email: options[:email], password: options[:password])

        individual = Individual.create(current_first_name: options[:first_name], current_last_name: options[:last_name])

        user.party = individual.party
        user.save!

        user.party.set_tenant!(options[:tenant], options[:tenant_reln_type])

        if options[:party_roles]
          options[:party_roles].each do |party_role|
            user.party.add_role_type(party_role)
          end
        end

        if options[:security_roles]
          options[:security_roles].each do |security_role|
            user.add_role(security_role)
          end
        end

        if options[:applications]
          options[:applications].each do |application|
            user.applications << application
          end
        end
      end

      user
    end
  end

  def profile_image
    self.party.images.scoped_by('is_profile_image', true).first
  end

  def set_profile_image(data, file_name)
    file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)

    data = FileAsset.adjust_image(data, '200x200')

    file_asset = self.party.add_file(data, File.join(file_support.root, 'file_assets', 'user', self.id.to_s, 'profile_image', file_name))
    file_asset.add_scope('is_profile_image', true)
  end

  def email_cannot_match_username_of_other_user
    unless User.where(:username => self.email).where('id != ?', self.id).first.nil?
      errors.add(:email, "In use by another user")
    end
  end

  # Revoke any valid auth tokens for this User
  #
  def revoke_all_auth_tokens
    auth_tokens.valid.destroy_all
  end

  # Revoke any auth token
  #
  def revoke_auth_token(token)
    current_token = auth_tokens.valid.where(token: token).first
    if current_token
      current_token.destroy
    end
  end

  # auth token used for mobile app security
  #
  def generate_auth_token!(expires_at=(Time.now + 30.days))
    auth_token = AuthToken.generate(expires_at)

    self.auth_tokens << auth_token
    self.save!

    auth_token
  end

  # Check if token is valid
  #
  def auth_token_valid?(token)
    !auth_tokens.where('token = ?', token).valid.first.nil?
  end

  # Set the auth_token for this User and remove all others
  #
  # @param token [String] token to save
  # @param expires_at [DateTime] DateTime when this token expires
  def set_auth_token!(token, expires_at)
    self.revoke_all_auth_tokens

    self.auth_tokens.create(token: token, expires_at: expires_at)
  end

  # Get the current valid auth token
  #
  def current_auth_token
    self.auth_tokens.valid.first
  end

  # This allows the disabling of the activation email sent via the sorcery user_activation submodule
  def send_activation_needed_email!
    super unless skip_activation_email
  end

  #these two methods allow us to assign instance level attributes that are not persisted.  These are used for mailers
  def instance_attributes
    @instance_attrs.nil? ? {} : @instance_attrs
  end

  def add_instance_attribute(k, v)
    @instance_attrs = {} if @instance_attrs.nil?
    @instance_attrs[k] = v
  end

  # roles this user does NOT have
  def roles_not
    party.roles_not
  end

  # roles this user has
  def roles
    party.security_roles
  end

  def has_role?(*passed_roles)
    result = false
    passed_roles.flatten!
    passed_roles.each do |role|
      role_iid = role.is_a?(SecurityRole) ? role.internal_identifier : role.to_s
      all_uniq_roles.each do |this_role|
        result = true if (this_role.internal_identifier == role_iid)
        break if result
      end
      break if result
    end
    result
  end

  def add_role(role)
    party.add_role(role)
  end

  alias :add_security_role :add_role

  def add_roles(*passed_roles)
    party.add_roles(*passed_roles)
  end

  alias :add_security_roles :add_roles

  def remove_roles(*passed_roles)
    party.remove_roles(*passed_roles)
  end

  alias :remove_security_roles :remove_roles

  def remove_role(role)
    party.remove_role(role)
  end

  alias :remove_security_role :remove_role

  def remove_all_roles
    party.remove_all_roles
  end

  alias :remove_all_security_roles :remove_all_roles

  # party records for the groups this user belongs to
  def group_parties
    Party.joins("JOIN #{group_member_join}")
  end

  # groups this user belongs to
  def groups
    Group.joins(:party).joins("JOIN #{group_member_join}")
  end

  # groups this user does NOT belong to
  def groups_not
    Group.joins(:party).joins("LEFT JOIN #{group_member_join}").where("party_relationships.id IS NULL")
  end

  # roles assigned to the groups this user belongs to
  def group_roles
    SecurityRole.joins(:parties).
      where(:parties => {:business_party_type => 'Group'}).
      where("parties.business_party_id IN (#{groups.select('groups.id').to_sql})")
  end

  # Add a group to this user
  #
  # @param group [Group] Group to add
  def add_group(group)
    group.add_user(self)
  end

  # Add multiple groups to this user
  #
  # @param _groups [Array] Groups to add
  def add_groups(_groups)
    _groups.each do |group|
      add_group(group)
    end
  end

  # Remove a group from this user
  #
  # @param group [Group] Group to remove
  def remove_group(group)
    group.remove_user(self)
  end

  # Remove multiple groups from this user
  #
  # @param _groups [Array] Groups to remove
  def remove_groups(_groups)
    _groups.each do |group|
      remove_group(group)
    end
  end

  # Remove all current groups from this user
  #
  def remove_all_groups
    groups.each do |group|
      remove_group(group)
    end
  end

  # composite roles for this user
  def all_roles
    SecurityRole.joins(:parties).joins("LEFT JOIN users ON parties.id=users.party_id").
    where("(parties.business_party_type='Group' AND
              parties.business_party_id IN (#{groups.select('groups.id').to_sql})) OR 
             (users.id=#{self.id})")
  end

  def all_uniq_roles
    all_roles.all.uniq
  end

  def group_capabilities
    Capability.includes(:capability_type).joins(:capability_type).joins(:capability_accessors).
      where(:capability_accessors => {:capability_accessor_record_type => "Group"}).
      where("capability_accessor_record_id IN (#{groups.select('groups.id').to_sql})")
  end

  def role_capabilities
    Capability.includes(:capability_type).joins(:capability_type).joins(:capability_accessors).
      where(:capability_accessors => {:capability_accessor_record_type => "SecurityRole"}).
      where("capability_accessor_record_id IN (#{all_roles.select('security_roles.id').to_sql})")
  end

  def all_capabilities
    Capability.includes(:capability_type).joins(:capability_type).joins(:capability_accessors).
    where("(capability_accessors.capability_accessor_record_type = 'Group' AND
                  capability_accessor_record_id IN (#{groups.select('groups.id').to_sql})) OR
                 (capability_accessors.capability_accessor_record_type = 'SecurityRole' AND
                  capability_accessor_record_id IN (#{all_roles.select('security_roles.id').to_sql})) OR
                 (capability_accessors.capability_accessor_record_type = 'User' AND
                  capability_accessor_record_id = #{self.id})")
  end

  def all_uniq_capabilities
    all_capabilities.all.uniq
  end

  def group_class_capabilities
    scope_type = ScopeType.find_by_internal_identifier('class')
    group_capabilities.where(:scope_type_id => scope_type.id)
  end

  def role_class_capabilities
    scope_type = ScopeType.find_by_internal_identifier('class')
    role_capabilities.where(:scope_type_id => scope_type.id)
  end

  def all_class_capabilities
    scope_type = ScopeType.find_by_internal_identifier('class')
    all_capabilities.where(:scope_type_id => scope_type.id)
  end

  def all_uniq_class_capabilities
    all_class_capabilities.all.uniq
  end

  def class_capabilities_to_hash
    all_uniq_class_capabilities.map { |capability|
      { capability_type_iid: capability.capability_type.internal_identifier,
        capability_type_description: capability.capability_type.description,
        capability_resource_type: capability.capability_resource_type
        }
    }.compact
  end

  def to_data_hash
    data = to_hash(only: [
                     :id,
                     :username,
                     :email,
                     :activation_state,
                     :last_login_at,
                     :last_logout_at,
                     :last_activity_at,
                     :failed_logins_count,
                     :created_at,
                     :time_zone,
                     :updated_at
                   ],
                   display_name: party.description,
                   is_admin: party.has_security_role?('admin'),
                   party: party.to_data_hash,
                   profile_image_url: profile_image.try(:fully_qualified_url)
                   )

    # add first name and last name if this party is an Individual
    if self.party.business_party.is_a?(Individual)
      data[:first_name] = self.party.business_party.current_first_name
      data[:last_name] = self.party.business_party.current_last_name
    end

    data
  end

  protected

  def group_member_join
    role_type = RoleType.find_by_internal_identifier('group_member')
    "party_relationships ON party_id_from = #{self.party.id} AND party_id_to = parties.id AND role_type_id_from=#{role_type.id}"
  end

end
