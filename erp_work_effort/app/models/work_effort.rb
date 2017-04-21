#### Table Definition ###########################
# create_table "work_efforts", :force => true do |t|
#   t.integer  "parent_id"
#   t.integer  "lft"
#   t.integer  "rgt"
#   t.integer  "facility_id"
#   t.integer  "projected_cost_money_id"
#   t.integer  "actual_cost_money_id"
#   t.integer  "fixed_asset_id"
#   t.integer  "work_effort_purpose_type_id"
#   t.integer  "work_effort_type_id"
#   t.string   "description"
#   t.string   "type"
#   t.datetime "start_at"
#   t.datetime "end_at"
#   t.integer  "work_effort_record_id"
#   t.string   "work_effort_record_type"
#   t.integer  "work_effort_item_id"
#   t.string   "work_effort_item_type"
#   t.datetime "created_at", :null => false
#   t.datetime "updated_at", :null => false
#   t.text     "comments"
#   t.integer  "percent_done"
#   t.integer  "duration"
#   t.string   "duration_unit"
#   t.integer  "effort"
#   t.string   "effort_unit"
#   t.datetime "base_line_start_at"
#   t.datetime "base_line_end_at"
#   t.integer  "base_line_percent_done"
#   t.integer  "project_id"
#   t.text     "custom_fields"
# end
#
# add_index "work_efforts", ["end_at"], :name => "index_work_efforts_on_end_at"
# add_index "work_efforts", ["fixed_asset_id"], :name => "index_work_efforts_on_fixed_asset_id"
# add_index "work_efforts", ["project_id"], :name => "work_effort_project_idx"
# add_index "work_efforts", ["work_effort_item_type", "work_effort_item_id"], :name => "work_item_idx"
# add_index "work_efforts", ["work_effort_record_id", "work_effort_record_type"], :name => "work_effort_record_id_type_idx"
#################################################

class WorkEffort < ActiveRecord::Base
  attr_protected :created_at, :updated_at

  cattr_accessor :task_status_complete_iid
  cattr_accessor :task_status_in_progress_iid
  cattr_accessor :task_resource_status_complete_iid

  @@task_status_complete_iid = 'task_status_complete'
  @@task_status_in_progress_iid = 'task_status_in_progress'
  @@task_resource_status_complete_iid = 'task_resource_status_complete'

  acts_as_nested_set
  include ErpTechSvcs::Utils::DefaultNestedSetMethods
  has_tracked_status

  ## How is this Work Effort related to business parties, requestors, workers, approvers
  has_party_roles
  has_contacts

  tracks_created_by_updated_by

  after_save :roll_up
  before_move :update_parent_status_before_move!
  after_move :update_parent_status!
  after_destroy :update_parent_status!
  before_destroy :check_work_order_item_fulfillments

  belongs_to :work_effort_item, :polymorphic => true

  belongs_to :project
  belongs_to :work_effort_type
  belongs_to :work_effort_purpose_type

  ## How is this Work Effort related to Work Order Items (order_line_items)
  has_many :work_order_item_fulfillments, :dependent => :destroy
  has_many :order_line_items, :through => :work_order_item_fulfillments

  ## How is a work effort assigned, it can be assigned to party roles which allow for generic assignment.
  has_and_belongs_to_many :role_types
  alias :role_type_assignments :role_types

  ## How is this Work Effort is assigned
  has_many :work_effort_party_assignments, :dependent => :destroy
  has_many :parties, :through => :work_effort_party_assignments do
    def work_resources
      role_types = RoleType.find_child_role_types(['work_resource'])

      where('work_effort_party_assignments.role_type_id' => role_types)
    end
  end

  ## What Fixed Assets (tools, equipment) are used in the execution of this Work Effort
  has_many :work_effort_fixed_asset_assignments, :dependent => :destroy
  has_many :fixed_assets, :through => :work_effort_fixed_asset_assignments

  ## What BizTxnEvents have been related to this WorkEffort
  has_many :work_effort_biz_txn_events, :dependent => :destroy
  has_many :biz_txn_events, :through => :work_effort_biz_txn_events

  ## Allow for polymorphic subtypes of this class
  belongs_to :work_effort_record, :polymorphic => true

  belongs_to :projected_cost, :class_name => 'Money', :foreign_key => 'projected_cost_money_id'
  belongs_to :actual_cost, :class_name => 'Money', :foreign_key => 'actual_cost_money_id'
  belongs_to :facility

  has_many :time_entries
  has_many :associated_transportation_routes, as: :associated_record
  has_many :transportation_routes, through: :associated_transportation_routes
  has_many :inventory_txns, as: :created_by, dependent: :destroy

  class << self

    # Filter records
    #
    # @param filters [Hash] a hash of filters to be applied,
    # @param statement [ActiveRecord::Relation] the query being built
    # @return [ActiveRecord::Relation] the query being built
    def apply_filters(filters, statement)
      work_efforts_tbl = WorkEffort.arel_table

      # filter by description
      unless filters[:description].blank?
        statement = statement.where(work_efforts_tbl[:description].matches("%#{filters[:description]}%"))
      end

      # filter by WorkEffortType
      unless filters[:work_effort_type_iids].blank?
        statement = statement.where(work_effort_type_id: WorkEffortType.where(internal_identifier: filters[:work_effort_type_iids]))
      end

      # filter by Status
      unless filters[:status].blank?
        statement = statement.with_current_status(filters[:status].split(','))
      end

      # filter by start_at
      unless filters[:start_date].blank?
        statement = statement.where(work_efforts_tbl[:start_at].gteq(Date.parse(filters[:start_date])))
      end

      # filter by end_at
      unless filters[:end_date].blank?
        statement = statement.where(work_efforts_tbl[:end_at].lteq(Date.parse(filters[:end_date])))
      end

      # filter by assigned to
      unless filters[:assigned_to_ids].blank?
        work_effort_party_assignments_tbl = WorkEffortPartyAssignment.arel_table

        statement = statement.joins(:work_effort_party_assignments)
        .where(work_effort_party_assignments_tbl[:role_type_id].in(RoleType.find_child_role_types([RoleType.work_resource]).collect(&:id)))
        .where(work_effort_party_assignments_tbl[:party_id].in(filters[:assigned_to_ids]))
      end

      # filter by project
      unless filters[:project_id].blank?
        statement = statement.where(work_efforts_tbl[:project_id].eq(filters[:project_id]))
      end

      # filter by projects
      unless filters[:project_ids].blank?
        statement = statement.where(work_efforts_tbl[:project_id].in(filters[:project_ids]))
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
      scope_by_party(dba_organization, {role_types: [RoleType.iid('dba_org')]})
    end

    alias scope_by_dba scope_by_dba_organization

    # scope by project
    #
    # @param project [Integer | Project | Array] either a id of Project record, a Project record, an array of Project records
    # or an array of Project ids
    #
    # @return [ActiveRecord::Relation]
    def scope_by_project(project)
      where(project_id: project)
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

      if options[:role_types]
        joins("inner join entity_party_roles as #{table_alias} on #{table_alias}.entity_record_type = 'WorkEffort'
                                     and #{table_alias}.entity_record_id = work_efforts.id and
                                     #{table_alias}.role_type_id in (#{RoleType.find_child_role_types(options[:role_types]).collect(&:id).join(',')})
                                     and #{table_alias}.party_id in (#{Party.select('id').where(id: party).to_sql})")

      else
        joins("inner join entity_party_roles as #{table_alias} on #{table_alias}.entity_record_type = 'WorkEffort'
                                     and #{table_alias}.entity_record_id = work_efforts.id
                                     and #{table_alias}.party_id in (#{Party.select('id').where(id: party).to_sql})")
      end
    end

    # scope by work efforts assigned to the passed user
    #
    # @param user [User] user to look for assignments
    # @param options [Hash] options to apply to this scope
    # @option options [Array] :role_types role types to include in the scope
    #
    # @return [ActiveRecord::Relation]
    def scope_by_user(user, options={})
      scope_by_party_assignment(user.party, options)
    end

    # scope by work efforts assigned to the passed party
    #
    # @param party [Party] party to look for assignments
    # @param options [Hash] options to apply to this scope
    # @option options [Array] :role_types role types to include in the scope
    #
    # @return [ActiveRecord::Relation]
    def scope_by_party_assignment(party, options={})
      statement = joins("join work_effort_party_assignments wepa on wepa.work_effort_id = work_efforts.id and wepa.party_id = #{party.id}")

      if options[:role_types]
        statement = statement.where("wepa.role_type_id" => RoleType.find_child_role_types(options[:role_types]))
      end

      statement
    end
  end

  # Destroy any OrderLineItems that are only related to this WorkEffort
  #
  def check_work_order_item_fulfillments
    order_line_items.each do |order_line_item|
      if order_line_item.order_txn_id.nil? && order_line_item.work_efforts.count == 1
        order_line_item.destroy
      end
    end
  end

  def to_s
    self.description
  end

  def to_label
    self.description
  end

  # Get dba_organzation info eventually going to be tenant
  def dba_organization
    find_party_by_role(RoleType.dba_org)
  end
  alias :tenant :dba_organization

  # Get assigned parties by role type
  #
  # @param role_types [Array] (['work_resource']) Array of role types to scope by
  # @return [Array] Assigned Parties
  def assigned_parties(role_types=['work_resource'])
    role_types = RoleType.find_child_role_types(role_types)

    Party.joins(work_effort_party_assignments: :role_type)
    .where(role_types: {id: role_types})
    .where(work_effort_party_assignments: {work_effort_id: self.id})
  end

  # Returns true if the party is assigned to WorkEffort
  #
  # @param party [Party] Party to check if it is assigned
  # @param role_types [Array] Array of role types to check the assignments for
  def party_assigned?(party, role_types=['work_resource'])
    !WorkEffort.joins(work_effort_party_assignments: :role_type)
    .where(role_types: {id: RoleType.find_child_role_types(role_types)})
    .where(work_effort_party_assignments: {work_effort_id: self.id})
    .where(work_effort_party_assignments: {party_id: party.id}).first.nil?
  end

  # Get comma sepeated description of all Parties assigned
  #
  # @param role_types [Array] (['work_resource']) Array of role types to scope by
  # @return [Array] descriptions of Parties comma separated
  def description_of_assigned_parties(role_types=['work_resource'])
    assigned_parties(role_types).collect do |item|
      item.party.description
    end.join(',')
  end

  # get all the assigned roles
  #
  # @return [Array] descriptions of role types comma separated
  def assigned_roles
    self.role_types.collect(&:description).join(',')
  end

  # get the current status of this work_effort
  #
  # @return [String] status
  def status
    current_status
  end

  # return true if this effort has been started, false otherwise
  #
  # @return [Boolean] true if started
  def started?
    current_status.nil? ? false : true
  end

  # return true if this effort has been completed, false otherwise
  #
  # @return [Boolean] true if completed
  def completed?
    finished_at.nil? ? false : true
  end

  # return true if this effort has been completed, false otherwise
  #
  # @return [Boolean]
  def finished?
    completed?
  end

  # Check if a party is allowed to enter time aganist this Work Effort
  #
  # @param party [Party] Party to test aganist
  # @return [Boolean] If time entries are allowed
  def time_entries_allowed?(party)
    self.party_assigned?(party) and self.current_status != @@task_status_complete_iid
  end

  def has_time_entries?
    self.time_entries.count != 0
  end

  def has_assigned_parties?
    self.work_effort_party_assignments.count != 0
  end

  # start work effort with initial_status (string)
  #
  # @param initial_status [String] status to start at
  def start(initial_status='')
    effort = self
    unless self.descendants.flatten!.nil?
      children = self.descendants.flatten
      effort = children.last
    end

    if current_status.nil?
      effort.current_status = initial_status
      effort.start_at = DateTime.now
      effort.save
    else
      raise 'Effort Already Started'
    end
  end

  # set current status of entity.
  #
  # This is overriding the default method to update the task assignments as well if the status is set to
  # complete
  #
  # @param args [String, TrackedStatusType, Array] This can be a string of the internal identifier of the
  # TrackedStatusType to set, a TrackedStatusType instance, or three params the status, options and party_id
  def current_status=(args)
    if args.is_a?(Array)
      status = args[0]
    else
      status = args
    end

    tracked_status_type = status.is_a?(TrackedStatusType) ? status : TrackedStatusType.find_by_internal_identifier(status.to_s)
    raise "TrackedStatusType does not exist #{status.to_s}" unless tracked_status_type

    # if passed status is current status then do nothing
    unless self.current_status_type && (self.current_status_type.id == tracked_status_type.id)
      if self.current_status_type
        _current_status = self.current_status_type.internal_identifier
      else
        _current_status = nil
      end

      super(args)

      if args.is_a?(Array)
        status = args[0]
      else
        status = args
      end

      if status.is_a? TrackedStatusType
        status = status.internal_identifier
      end

      if status == @@task_status_complete_iid
        complete!
      else
        # if there were InventoryTxns that were applied and this task went from complete to pending we
        # need to unapply those InventoryTxns
        if _current_status && _current_status == @@task_status_complete_iid
          self.inventory_txns.each do |inventory_txn|
            inventory_txn.unapply!
          end
        end

        update_parent_status!
      end
    end
  end

  # Check if all this WorkEfforts descendants are complete.
  # An optional ignored_id can be passed for a node that you don't want to check if
  # it is complete
  #
  # @param ingored_id [Integer] Id of WorkEffort to ingnore it's status
  def descendants_complete?(ignored_id=nil)
    all_complete = true

    if descendants.count == 0
      all_complete = false
    else
      descendants.each do |node|
        unless node.id == ignored_id
          if !node.is_complete?
            all_complete = false
            break
          end
        end
      end
    end

    all_complete
  end

  def is_complete?
    (current_status == @@task_status_complete_iid)
  end

  # get total hours for this WorkEffort by TimeEntries
  #
  def total_hours_in_seconds
    if leaf?
      time_entries.sum(:regular_hours_in_seconds)
    else
      descendants.collect(&:total_hours_in_seconds)
    end
  end

  # get total hours for this WorkEffort by TimeEntries
  def total_hours
    if self.leaf?
      time_entries.all.sum { |time_entry| time_entry.hours }
    else
      self.descendants.collect(&:total_hours)
    end
  end

  # Calculate totals for children
  #
  def calculate_children_totals
    self.start_at = self.descendants.order('start_at asc').first.start_at
    self.end_at = self.descendants.order('end_at desc').last.end_at

    lowest_duration_unit = nil
    duration_total = nil
    percent_done_total = 0.0
    self.descendants.collect do |child|
      if child.leaf?
        if child.duration and child.duration > 0
          duration_total = 0.0 if duration_total.nil?

          duration_in_hours = ErpWorkEffort::Services::UnitConverter.convert_unit(child.duration.to_f, child.duration_unit.to_sym, :h)

          percent_done_total += (duration_in_hours.to_f * (child.percent_done.to_f / 100))

          if lowest_duration_unit.nil? || ErpWorkEffort::Services::UnitConverter.new(lowest_duration_unit) > child.duration_unit.to_sym
            lowest_duration_unit = child.duration_unit.to_sym
          end

          duration_total += duration_in_hours
        end
      end
    end

    if duration_total
      self.duration_unit = lowest_duration_unit.to_s
      if lowest_duration_unit != :h
        self.duration = ErpWorkEffort::Services::UnitConverter.convert_unit(duration_total.to_f, :h, lowest_duration_unit)
      else
        self.duration = duration_total
      end

      self.percent_done = (((percent_done_total / duration_total.to_f).round(2)) * 100)
    end

    lowest_effort_unit = nil
    effort_total = nil
    self.descendants.collect do |child|
      if child.leaf?
        if child.effort and child.effort > 0
          effort_total = 0.0 if effort_total.nil?

          if lowest_effort_unit.nil? || ErpWorkEffort::Services::UnitConverter.new(lowest_effort_unit) > child.effort_unit.to_sym
            lowest_effort_unit = child.effort_unit.to_sym
          end

          effort_total += ErpWorkEffort::Services::UnitConverter.convert_unit(child.effort.to_f, child.effort_unit.to_sym, :h)
        end
      end
    end

    if effort_total
      self.effort_unit = lowest_effort_unit.to_s
      if lowest_effort_unit != :h
        self.effort = ErpWorkEffort::Services::UnitConverter.convert_unit(effort_total.to_f, :h, lowest_effort_unit)
      else
        self.effort = effort_total
      end
    end

    self.save!
  end

  # Roll up totals to parents
  #
  def roll_up
    if self.parent
      self.parent.calculate_children_totals
      self.parent.roll_up
    end
  end

  # converts this record a hash data representation
  #
  # @return [Hash] data of record
  def to_data_hash
    data = to_hash(only: [
                     :id,
                     {leaf?: :leaf},
                     :parent_id,
                     :description,
                     :start_at,
                     :end_at,
                     :percent_done,
                     :duration,
                     :duration_unit,
                     :effort,
                     :effort_unit,
                     :comments,
                     :sequence,
                     :created_at,
                     :updated_at,
                     :current_status
                   ]
                   )

    data[:status] = self.try(:current_status_application).try(:to_data_hash)
    data[:work_effort_type] = self.try(:work_effort_type).try(:to_data_hash)

    data
  end

  # Clone this WorkEffort. Copies any assignments and watchers
  #
  def clone
    _copy = self.dup
    _copy.save!

    # copy assignments
    self.work_effort_party_assignments.each do |work_effort_party_assignment|
      _work_effort_party_assignment_copy = work_effort_party_assignment.dup
      _work_effort_party_assignment_copy.work_effort_id = _copy.id
      _work_effort_party_assignment_copy.save!
    end

    # copy party roles
    self.entity_party_roles.each do |entity_party_role|
      entity_party_role = entity_party_role.dup
      entity_party_role.entity_record_id = _copy.id
      entity_party_role.save!
    end

    _copy
  end

  protected

  # determine difference in minutes between two times
  #
  # @param time_one [Time] first time
  # @param time_two [Time] second time
  # @return [Integer] time difference in minutes
  def time_diff_in_minutes (time_one, time_two)
    (((time_one - time_two).round) / 60)
  end

  private

  # completes work effort by setting finished at to Time.now and calculates
  # actual_completion_time in minutes
  #
  def complete!
    self.end_at = Time.now
    self.save

    self.work_effort_party_assignments.each do |assignment|
      assignment.current_status = @@task_resource_status_complete_iid
    end

    # close all open time entries
    time_entries.open_entries.each do |time_entry|
      time_entry.thru_datetime = Time.now

      time_entry.calculate_regular_hours_in_seconds!

      time_entry.update_task_assignment_status(@@task_resource_status_complete_iid)
    end

    # apply any inventory_txns related to this task
    self.inventory_txns.each do |inventory_txn|
      inventory_txn.apply!
    end

    update_parent_status!
  end

  # Update the parent statues based on it's child nodes
  #
  def update_parent_status!
    if parent
      _parent = parent
      while _parent
        if _parent.descendants_complete?
          _parent.current_status = @@task_status_complete_iid
        elsif _parent.current_status == @@task_status_complete_iid
          _parent.current_status = @@task_status_in_progress_iid
        end
        _parent = _parent.parent
      end
    end
  end

  # Update the parent statues based on it's child nodes before a node is moved
  # ingnoring the node that is being moved
  #
  def update_parent_status_before_move!
    if parent
      _parent = parent
      while _parent
        if _parent.descendants_complete?(self.id)
          _parent.current_status = @@task_status_complete_iid
        elsif _parent.current_status == @@task_status_complete_iid
          _parent.current_status = @@task_status_in_progress_iid
        end
        _parent = _parent.parent
      end
    end
  end

end
