## Work Effort Assignments - what is necessary to complete this work effort

## work_effort_party_assignments
## this is straight entity_party_role pattern with from and thru dates, but we are keeping
## the DMRB name for this entity.

# creat e_table :work_effort_party_assignments do |t|
#   foreign key references
#   t.references :work_effort
#   t.references :role_type
#   t.references :party
#
#   t.datetime :assigned_from
#   t.datetime :assigned_thru
#
#   t.text :comments
#
#   t.integer :resource_allocation
#
#   t.timestamps
#   end
#
#   add_index :work_effort_party_assignments, :assigned_from
#   add_index :work_effort_party_assignments, :assigned_thru
#   add_index :work_effort_party_assignments, :work_effort_id
#   add_index :work_effort_party_assignments, :party_id

class WorkEffortPartyAssignment < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  belongs_to :work_effort
  belongs_to :party
  belongs_to :role_type

  validates_uniqueness_of :party_id, scope: [:work_effort_id, :role_type_id]

  has_tracked_status
  tracks_created_by_updated_by

  class << self

    # Filter records
    #
    # @param filters [Hash] a hash of filters to be applied,
    # @param statement [ActiveRecord::Relation] the query being built
    # @return [ActiveRecord::Relation] the query being built
    def apply_filters(filters, statement)
      # filter by project
      unless filters[:project_id].blank?
        statement = statement.scope_by_project(filters[:project_id])
      end

      # filter by project
      unless filters[:project_ids].blank?
        statement = statement.scope_by_project(filters[:project_ids])
      end

      # filter by work_effort
      unless filters[:work_effort_id].blank?
        if filters[:work_effort_id].is_a? String
          ids = filters[:work_effort_id].split(',')
        else
          ids = filters[:work_effort_id]
        end

        statement = statement.scope_by_work_effort(ids)
      end

      # filter by status
      unless filters[:status].blank?
        statement = statement.with_current_status(filters[:status].split(','))
      end

      # filter by parties
      unless filters[:parties].blank?
        data = JSON.parse(filters[:parties])

        statement = statement.scope_by_party(data['party_ids'].split(','),
                                             {role_types: RoleType.where('internal_identifier' => data['role_types'].split(','))})
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
      scope_by_party(dba_organization, {role_types: ['dba_org']})
    end

    alias scope_by_dba scope_by_dba_organization

    # scope by project
    #
    # @param project [Integer | Project | Array] either a id of Project record, a Project record, an array of Project records
    # or an array of Project ids
    #
    # @return [ActiveRecord::Relation]
    def scope_by_project(project)
      joins(:work_effort).where('work_efforts.project_id' => project)
    end

    # scope by work_effort
    #
    # @param work_effort [Integer | WorkEffort | Array] either a id of WorkEffort record, a WorkEffort record, an array of WorkEffort records
    # or an array of WorkEffort ids
    #
    # @return [ActiveRecord::Relation]
    def scope_by_work_effort(work_effort)
      where(work_effort_id: work_effort)
    end

    # scope by party
    #
    # @param party [Integer | Party | Array] either a id of Party record, a Party record, an array of Party records
    # or an array of Party ids
    # @param options [Hash] options to apply to this scope
    # @option options [Array] :role_types role types to include in the scope
    #
    # @return [ActiveRecord::Relation]
    def scope_by_party(party, options={})
      table_alias = String.random

      statement = joins(:work_effort)

      if options[:role_types]
        statement = statement.joins("inner join entity_party_roles as #{table_alias} on #{table_alias}.entity_record_type = 'WorkEffort'
                                     and #{table_alias}.entity_record_id = work_efforts.id and
                                     #{table_alias}.role_type_id in (#{RoleType.find_child_role_types(options[:role_types]).collect(&:id).join(',')})
                                     and #{table_alias}.party_id in (#{Party.select('id').where(id: party).to_sql})")

      else
        statement = statement.joins("inner join entity_party_roles as #{table_alias} on #{table_alias}.entity_record_type = 'WorkEffort'
                                     and #{table_alias}.entity_record_id = work_efforts.id
                                     and #{table_alias}.party_id in (#{Party.select('id').where(id: party).to_sql})")
      end

      statement
    end
  end

  # converts this record a hash data representation
  #
  # @return [Hash] data of record
  def to_data_hash
    data = to_hash(only: [:id, :resource_allocation])

    data[:status] = self.try(:current_status_application).try(:to_data_hash)
    data[:party] = self.try(:party).try(:to_data_hash)
    data[:work_effort] = self.try(:work_effort).try(:to_data_hash)

    data
  end

end
