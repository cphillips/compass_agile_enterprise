class BizTxnType < ActiveRecord::Base
  attr_protected :created_at, :updated_at

	acts_as_nested_set
	include ErpTechSvcs::Utils::DefaultNestedSetMethods
	acts_as_erp_type

  belongs_to_erp_type :parent, :class_name => "BizTxnType"

  # this method handles default behavior for find by type and subtype
  def self.find_by_type_and_subtype(txn_type, txn_subtype)
    return self.find_by_type_and_subtype_eid(txn_type, txn_subtype)
  end

  # find by type Internal Identifier and subtype Internal Identifier
  def self.find_by_type_and_subtype_iid(txn_type, txn_subtype)
    txn_type_recs = find_all_by_internal_identifier(txn_type.strip)
    return nil if txn_type_recs.blank?
    txn_type_recs.each do |txn_type_rec|
      txn_subtype_rec = find_by_parent_id_and_internal_identifier(txn_type_rec.id, txn_subtype.strip)
      return txn_subtype_rec unless txn_subtype_rec.nil?
    end
    return nil
  end

  # find by type External Identifier and subtype External Identifier
  def self.find_by_type_and_subtype_eid(txn_type, txn_subtype)
    txn_type_recs = find_all_by_external_identifier(txn_type.strip)
    return nil if txn_type_recs.blank?
    txn_type_recs.each do |txn_type_rec|
      txn_subtype_rec = find_by_parent_id_and_external_identifier(txn_type_rec.id, txn_subtype.strip)
      return txn_subtype_rec unless txn_subtype_rec.nil?
    end
    return nil
  end

  # finds all child for given types.
  #
  # @param biz_txn_types [Array] BizTxnType internal identifiers or records
  # @returns [Array] BizTxnTypes types based and any of their children in a flat array
  def self.find_child_types(biz_txn_types)
    all_biz_txn_types = []

    biz_txn_types.each do |biz_txn_type|

      if biz_txn_type.is_a?(String)
        biz_txn_type = BizTxnType.iid(biz_txn_type)
      end

      all_biz_txn_types.concat biz_txn_type.self_and_descendants
    end

    all_biz_txn_types.flatten
  end

  def to_data_hash
    to_hash(:only => [:id, :description, :internal_identifier, :created_at, :updated_at])
  end

end
