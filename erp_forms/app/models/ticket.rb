class Ticket < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  belongs_to :user, :foreign_key => 'assigned_to_id'

  acts_as_dynamic_form_model
  has_file_assets
  has_dynamic_forms
  has_dynamic_data
  acts_as_commentable
  
  def send_email(subject='')
    begin
      WebsiteInquiryMailer.inquiry(self, subject).deliver
    rescue => ex
      system_user = Party.find_by_description('Compass AE')
      AuditLog.custom_application_log_message(system_user, ex)
    end
  end
end
