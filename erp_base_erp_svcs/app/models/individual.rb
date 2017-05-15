# create_table :individuals do |t|
#   t.column :party_id, :integer
#   t.column :current_last_name, :string
#   t.column :current_first_name, :string
#   t.column :current_middle_name, :string
#   t.column :current_personal_title, :string
#   t.column :current_suffix, :string
#   t.column :current_nickname, :string
#   t.column :gender, :string, :limit => 1
#   t.column :birth_date, :date
#   t.column :height, :decimal, :precision => 5, :scale => 2
#   t.column :weight, :integer
#   t.column :mothers_maiden_name, :string
#   t.column :marital_status, :string, :limit => 1
#   t.column :social_security_number, :string
#   t.column :current_passport_number, :integer
#
#   t.column :current_passport_expire_date, :date
#   t.column :total_years_work_experience, :integer
#   t.column :comments, :string
#   t.column :encrypted_ssn, :string
#   t.column :temp_ssn, :string
#   t.column :salt, :string
#   t.column :ssn_last_four, :string
#   t.timestamps
# end
# add_index :individuals, :party_id

class Individual < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  after_create :create_party
  after_save :save_party
  after_destroy :destroy_party

  has_one :party, :as => :business_party

  attr_encrypted :ssn,
    key: Rails.application.config.erp_base_erp_svcs.encryption_key,
    attribute: :encrypted_ssn,
    algorithm: 'aes-256-cbc',
    mode: :single_iv_and_salt,
    insecure_mode: true

  def after_initialize
    self.salt ||= Digest::SHA256.hexdigest((Time.now.to_i * rand(5)).to_s)
  end

  alias :social_security_number= :ssn=
  alias :social_security_number :ssn

  before_update :update_ssn_last_4

  def update_ssn_last_4
    if social_security_number
      self.ssn_last_four = social_security_number.split(//).last(4).join
    end
  end

  # Get dba_organzation info eventually going to be tenant
  def dba_organization
    self.try(:party).try(:dba_organization)
  end
  alias :tenant :dba_organization

  def formatted_ssn_label
    (self.ssn_last_four.blank?) ? "" : "XXX-XX-#{self.ssn_last_four}"
  end

  def self.from_registered_user(a_user)
    ind = Individual.new
    ind.current_first_name = a_user.first_name
    ind.current_last_name = a_user.last_name

    #this is necessary because this is where the callback creates the party instance.
    ind.save

    a_user.party = ind.party
    a_user.save
    ind.save
    #this is necessary because save returns a boolean, not the saved object
    return ind
  end

  def create_party
    unless self.party
      pty = Party.new
      pty.description = [current_personal_title, current_first_name, current_last_name].join(' ').strip
      pty.business_party = self
      pty.save
      self.party = pty
      self.save
    end
  end

  def save_party
    # TODO revisit this later, a lot of complaints about the description not getting updated
    #if self.party.description.blank? && (!current_first_name.blank? && !current_last_name.blank?)
    self.party.description = [current_personal_title, current_first_name, current_last_name].join(' ').strip
    self.party.save
    #end
  end

  def destroy_party
    if self.party
      self.party.destroy
    end
  end

  def to_label
    "#{current_first_name} #{current_last_name}"
  end
end
