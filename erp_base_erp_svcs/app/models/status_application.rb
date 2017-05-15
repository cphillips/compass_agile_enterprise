#  create_table :status_applications do |t|
#    t.references :tracked_status_type
#    t.references :status_application_record, :polymorphic => true
#    t.references :party
#    t.datetime :from_date
#    t.datetime :thru_date
#    t.column :comments, :string
#
#    t.timestamps
#  end
#
#  add_index :status_applications, [:status_application_record_id, :status_application_record_type], :name => 'status_applications_record_idx'
#  add_index :status_applications, :tracked_status_type_id, :name => 'tracked_status_type_id_idx'
#  add_index :status_applications, :from_date, :name => 'from_date_idx'
#  add_index :status_applications, :thru_date, :name => 'thru_date_idx'

class StatusApplication < ActiveRecord::Base

  belongs_to :tracked_status_type
  belongs_to :status_application_record, :polymorphic => true

  belongs_to :party

  validates :tracked_status_type, presence: true

  def username
    user_name = "System"
    unless party.nil?
      unless party.user.nil?
        user_name = party.user.username
      end
    end

    user_name
  end

  def to_data_hash
    data = to_hash(only: [:id,:created_at,:updated_at], username: username)

    data[:tracked_status_type] = tracked_status_type.to_data_hash

    data
  end

end
