class FixedAsset < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  tracks_created_by_updated_by

  belongs_to :fixed_asset_type
  belongs_to :fixed_asset_record, :polymorphic => true
  has_many :fixed_asset_party_roles

  def to_data_hash
    to_hash(only: [:id, :description, :created_at, :updated_at])
  end

end
