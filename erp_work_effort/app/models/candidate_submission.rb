class CandidateSubmission < ActiveRecord::Base

  # create_table :candidate_submissions do |t|
  #   t.integer :order_line_item_id
  #   t.string  :description
  #   t.string  :internal_identifier
  #   t.string  :accepted
  #   t.text    :custom_fields
  #   t.timestamps

  belongs_to :order_line_item

  attr_protected :created_at, :updated_at

  has_tracked_status

  is_json :custom_fields

  #must be after is_json

  # helper method to get dba_organization related to this candidate_submission's
  # order line item
  def dba_organization
    order_line_item = OrderLineItem.find(order_line_item_id)
    unless order_line_item.nil?
      order_line_item.dba_organization
    end
  end

  def clone
    new_candidate_submission = CandidateSubmission.new
    new_candidate_submission.description = self.description
    new_candidate_submission.internal_identifier = self.internal_identifier
    new_candidate_submission.accepted = self.accepted
    new_candidate_submission.custom_fields = self.custom_fields
    new_candidate_submission.save!

    new_candidate_submission
  end
end

