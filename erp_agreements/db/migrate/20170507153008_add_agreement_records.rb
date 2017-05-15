class AddAgreementRecords < ActiveRecord::Migration
  def up
    unless table_exists?(:agreement_records)
      create_table :agreement_records do |t|
        t.references :agreement
        t.references :agreement_role_type
        t.references :governed_record, polymorphic: true

        t.timestamps
      end

      add_index :agreement_records, :agreement_id, name: 'agreement_record_agreement_id_idx'
      add_index :agreement_records, :agreement_role_type_id, name: 'agreement_record_role_type_idx'
      add_index :agreement_records, [:governed_record_id, :governed_record_type], name: 'agreement_record_governed_record_idx'
    end
  end

  def down
    unless table_exists?(:agreement_records)
      drop_table :agreement_records
    end
  end
end
