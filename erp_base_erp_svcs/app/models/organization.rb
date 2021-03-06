class Organization < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  after_create :create_party
  after_save :save_party
  after_destroy :destroy_party

  has_one :party, :as => :business_party

  def create_party
    unless self.party
      pty = Party.new
      pty.description = self.description
      pty.business_party = self

      pty.save
      self.party = pty
      self.save
    end
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

  def to_label
    "#{description}"
  end

end
