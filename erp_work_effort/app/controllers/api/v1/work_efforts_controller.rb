module API
  module V1
    class WorkEffortsController < BaseController

=begin

 @api {get} /api/v1/work_efforts Index
 @apiVersion 1.0.0
 @apiName GetWorkEfforts
 @apiGroup WorkEffort

 @apiParam {Number} [project_id] Project ID to scope by
 @apiParam {String} [status] Comma separated list of TrackedStatusType internal identifiers to scope by
 @apiParam {String} [parties] JSON encoded object containing comma separated separated party ids and role types to scope by

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Array} work_efforts List of WorkEfforts
 @apiSuccess {Number} work_efforts.id Id of WorkEffort
 @apiSuccess {Boolean} work_efforts.leaf true If this WorkEffort is a leaf
 @apiSuccess {Number} work_efforts.parent_id Parent ID of WorkEffort
 @apiSuccess {String} work_efforts.description Description of WorkEffort
 @apiSuccess {DateTime} work_efforts.start_at Start At of WorkEffort
 @apiSuccess {DateTime} work_efforts.end_at End At of WorkEffort
 @apiSuccess {Decimal} work_efforts.percent_done Percent done of WorkEffort
 @apiSuccess {Number} work_efforts.duration Duration of WorkEffort
 @apiSuccess {String} work_efforts.duration_unit Duration Unit of WorkEffort
 @apiSuccess {Number} work_efforts.effort Effort of WorkEffort
 @apiSuccess {String} work_efforts.effort_unit Effort Unit of WorkEffort
 @apiSuccess {String} work_efforts.comments Comments on WorkEffort
 @apiSuccess {Number} work_efforts.sequence Sequence of WorkEffort
 @apiSuccess {DateTime} work_efforts.created_at When the WorkEffort was created
 @apiSuccess {DateTime} work_efforts.updated_at When the WorkEffort was updated

=end

      def index
        query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys

        work_efforts = WorkEffort.where("work_efforts.parent_id is null")

        if query_filter[:project_id].blank?
          # scope by user if that option is passed and no parties are passed to filter by
          if params[:scope_by_user].present? and params[:scope_by_user].to_bool
            work_efforts = work_efforts.scope_by_user(current_user, {role_types: [RoleType.iid('work_resource')]})

            # scope by dba organization if we are not scoping by user or filtering by parties and there is no project_id
          else
            dba_organizations = [current_user.party.dba_organization]
            dba_organizations = dba_organizations.concat(current_user.party.dba_organization.child_dba_organizations)
            work_efforts = work_efforts.scope_by_dba_organization(dba_organizations)
          end
        end

        # apply filters
        work_efforts = WorkEffort.apply_filters(query_filter, work_efforts)

        work_efforts = work_efforts.order("sequence ASC").uniq

        render :json => {success: true,
                         total: work_efforts.count,
                         work_efforts: work_efforts.map { |work_effort| work_effort.to_data_hash }}
      end

=begin

 @api {get} /api/v1/work_efforts/:id Show
 @apiVersion 1.0.0
 @apiName GetWorkEffort
 @apiGroup WorkEffort

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Object} work_effort Work Effort record
 @apiSuccess {Number} work_effort.id Id of WorkEffort
 @apiSuccess {Boolean} work_effort.leaf true If this WorkEffort is a leaf
 @apiSuccess {Number} work_effort.parent_id Parent ID of WorkEffort
 @apiSuccess {String} work_effort.description Description of WorkEffort
 @apiSuccess {DateTime} work_effort.start_at Start At of WorkEffort
 @apiSuccess {DateTime} work_effort.end_at End At of WorkEffort
 @apiSuccess {Decimal} work_effort.percent_done Percent done of WorkEffort
 @apiSuccess {Number} work_effort.duration Duration of WorkEffort
 @apiSuccess {String} work_effort.duration_unit Duration Unit of WorkEffort
 @apiSuccess {Number} work_effort.effort Effort of WorkEffort
 @apiSuccess {String} work_effort.effort_unit Effort Unit of WorkEffort
 @apiSuccess {String} work_effort.comments Comments on WorkEffort
 @apiSuccess {Number} work_effort.sequence Sequence of WorkEffort
 @apiSuccess {DateTime} work_effort.created_at When the WorkEffort was created
 @apiSuccess {DateTime} work_effort.updated_at When the WorkEffort was updated

=end

      def show
        work_effort = WorkEffort.find(params[:id])

        respond_to do |format|
          # if a tree format was requested then respond with the children of this WorkEffort
          format.tree do
            render :json => {success: true, work_efforts: WorkEffort.where(parent_id: work_effort).order("sequence ASC").collect { |child| child.to_data_hash }}
          end

          # if a json format was requested then respond with the WorkEffort in json format
          format.json do
            render :json => {success: true, work_effort: work_effort.to_data_hash}
          end
        end
      end

=begin

  @api {post} /api/v1/work_efforts Create
  @apiVersion 1.0.0
  @apiName CreateWorkEffort
  @apiGroup WorkEffort

  @apiParam {Number} [project_id] ID of Project to create WorkEfforts under
  @apiParam {Array} work_efforts Array of WorkEfforts to update
  @apiParam {String} work_efforts.description Description of WorkEffort
  @apiParam {DateTime} [work_efforts.start_at] Start At of WorkEffort
  @apiParam {DateTime} [work_efforts.end_at] End At of WorkEffort
  @apiParam {Decimal} [work_efforts.percent_done] Percent done of WorkEffort
  @apiParam {Number} [work_efforts.duration] Duration of WorkEffort
  @apiParam {String} [work_efforts.duration_unit] Duration Unit of WorkEffort
  @apiParam {Number} [work_efforts.effort] Effort of WorkEffort
  @apiParam {String} [work_efforts.effort_unit] Effort Unit of WorkEffort
  @apiParam {String} [work_efforts.comments] Comments on WorkEffort
  @apiParam {Number} [work_efforts.sequence] Sequence of WorkEffort
  @apiParam {Number} [work_efforts.parent_id ID] of Parent WorkEffort to put the newly created WorkEfforts under
  @apiParam {Number} [work_efforts.biz_txn_event_id] BizTxnEvent to relate to this WorkEffort

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} work_efforts Array of created WorkEfforts
  @apiSuccess {Number} work_efforts.id Id of WorkEffort
  @apiSuccess {Boolean} work_efforts.leaf true If this WorkEffort is a leaf
  @apiSuccess {Number} work_efforts.parent_id Parent ID of WorkEffort
  @apiSuccess {String} work_efforts.description Description of WorkEffort
  @apiSuccess {DateTime} work_efforts.start_at Start At of WorkEffort
  @apiSuccess {DateTime} work_efforts.end_at End At of WorkEffort
  @apiSuccess {Decimal} work_efforts.percent_done Percent done of WorkEffort
  @apiSuccess {Number} work_efforts.duration Duration of WorkEffort
  @apiSuccess {String} work_efforts.duration_unit Duration Unit of WorkEffort
  @apiSuccess {Number} work_efforts.effort Effort of WorkEffort
  @apiSuccess {String} work_efforts.effort_unit Effort Unit of WorkEffort
  @apiSuccess {String} work_efforts.comments Comments on WorkEffort
  @apiSuccess {Number} work_efforts.sequence Sequence of WorkEffort
  @apiSuccess {DateTime} work_efforts.created_at When the WorkEffort was created
  @apiSuccess {DateTime} work_efforts.updated_at When the WorkEffort was updated

=end

      def create
        begin
          ActiveRecord::Base.connection.transaction do
            work_efforts = []

            if params[:work_efforts]
              params[:work_efforts].each do |work_effort_data|
                work_efforts << create_work_effort(work_effort_data)
              end
            else
              work_efforts << create_work_effort(params)
            end

            render :json => {success: true, work_efforts: work_efforts.map { |work_effort| work_effort.to_data_hash }}

          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error creating Work Effort'}
        end
      end

=begin

  @api {put} /api/v1/work_efforts/:id Update
  @apiVersion 1.0.0
  @apiName UpdateWorkEffort
  @apiGroup WorkEffort

  @apiParam {Number} [project_id] ID of Project to put WorkEfforts under
  @apiParam {Array} work_efforts Array of WorkEfforts to create
  @apiParam {String} [work_efforts.description] Description of WorkEffort
  @apiParam {DateTime} [work_efforts.start_at] Start At of WorkEffort
  @apiParam {DateTime} [work_efforts.end_at] End At of WorkEffort
  @apiParam {Decimal} [work_efforts.percent_done] Percent done of WorkEffort
  @apiParam {Number} [work_efforts.duration] Duration of WorkEffort
  @apiParam {String} [work_efforts.duration_unit] Duration Unit of WorkEffort
  @apiParam {Number} [work_efforts.effort] Effort of WorkEffort
  @apiParam {String} [work_efforts.effort_unit] Effort Unit of WorkEffort
  @apiParam {String} [work_efforts.comments] Comments on WorkEffort
  @apiParam {Number} [work_efforts.sequence] Sequence of WorkEffort
  @apiParam {Number} [work_efforts.parent_id ID] of Parent WorkEffort to put the updated WorkEfforts under

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} work_efforts Array of created WorkEfforts
  @apiSuccess {Number} work_efforts.id Id of WorkEffort
  @apiSuccess {Boolean} work_efforts.leaf true If this WorkEffort is a leaf
  @apiSuccess {Number} work_efforts.parent_id Parent ID of WorkEffort
  @apiSuccess {String} work_efforts.description Description of WorkEffort
  @apiSuccess {DateTime} work_efforts.start_at Start At of WorkEffort
  @apiSuccess {DateTime} work_efforts.end_at End At of WorkEffort
  @apiSuccess {Decimal} work_efforts.percent_done Percent done of WorkEffort
  @apiSuccess {Number} work_efforts.duration Duration of WorkEffort
  @apiSuccess {String} work_efforts.duration_unit Duration Unit of WorkEffort
  @apiSuccess {Number} work_efforts.effort Effort of WorkEffort
  @apiSuccess {String} work_efforts.effort_unit Effort Unit of WorkEffort
  @apiSuccess {String} work_efforts.comments Comments on WorkEffort
  @apiSuccess {Number} work_efforts.sequence Sequence of WorkEffort
  @apiSuccess {DateTime} work_efforts.created_at When the WorkEffort was created
  @apiSuccess {DateTime} work_efforts.updated_at When the WorkEffort was updated

=end

      def update
        begin
          ActiveRecord::Base.connection.transaction do
            work_efforts = []

            if params[:work_efforts]
              params[:work_efforts].each do |work_effort_data|
                work_efforts << update_work_effort(work_effort_data)
              end
            else
              work_efforts << update_work_effort(params)
            end

            render :json => {success: true, work_efforts: work_efforts.map { |work_effort| work_effort.to_data_hash }}

          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error updating Work Effort'}
        end
      end

=begin

  @api {delete} /api/v1/work_efforts/:id Delete
  @apiVersion 1.0.0
  @apiName DeleteWorkEffort
  @apiGroup WorkEffort

  @apiSuccess {Boolean} success True if the request was successful

=end

      def destroy
        work_effort = WorkEffort.find(params[:id])

        begin
          ActiveRecord::Base.connection.transaction do

            render json: {success: work_effort.destroy}

          end
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error destroying Work Effort'}
        end
      end

=begin

  @api {get} /api/v1/work_efforts/:id/time_entries_allowed TimeEntriesAllowed
  @apiVersion 1.0.0
  @apiName WorkEffortTimeEntriesAllowed
  @apiGroup WorkEffort

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Boolean} allowed True if time entries are allowed

=end

      def time_entries_allowed
        work_effort = WorkEffort.find(params[:id])
        party = params[:party_id].blank? ? current_user.party : Party.find(params[:party_id])

        render json: {success: true, allowed: work_effort.time_entries_allowed?(party)}
      end

=begin

  @api {put} /api/v1/work_efforts/:id/update_status UpdateStatus
  @apiVersion 1.0.0
  @apiName UpdateWorkEffortStatus
  @apiGroup WorkEffort

  @apiParam {String} status Internal identifier of status that should be set

  @apiSuccess {Boolean} success True if the request was successful

=end

      def update_status
        work_effort = WorkEffort.find(params[:id])

        work_effort.current_status = params[:status]

        render :json => {:success => true}
      end

      protected

      def create_work_effort(data)
        work_effort = WorkEffort.new
        work_effort.description = data[:description].strip

        if params[:project_id].present?
          if params[:project_id].to_i != 0
            work_effort.project_id = params[:project_id]
          end
        end

        if data[:start_at].present?
          work_effort.start_at = Time.parse(data[:start_at]).in_time_zone.utc
        end

        if data[:end_at].present?
          work_effort.end_at = Time.parse(data[:end_at]).in_time_zone.utc
        end

        if data[:percent_done].present?
          work_effort.percent_done = data[:percent_done]
        end

        if data[:duration].present?
          work_effort.duration = data[:duration]
        end

        if data[:duration_unit].present?
          work_effort.duration_unit = data[:duration_unit]
        end

        if data[:effort].present?
          work_effort.effort = data[:effort]
        end

        if data[:effort_unit].present?
          work_effort.effort_unit = data[:effort_unit]
        end

        if data[:comments].present?
          work_effort.comments = data[:comments].strip
        end

        if data[:sequence].present?
          work_effort.sequence = data[:sequence]
        end

        if data[:status].present?
          if data[:status].is_a? String
            work_effort.current_status = TrackedStatusType.iid(data[:status])
          else
            work_effort.current_status = TrackedStatusType.iid(data[:status][:tracked_status_type][:internal_identifier])
          end
        end

        if data[:work_effort_type].present?
          if data[:work_effort_type].is_a? String
            work_effort.work_effort_type = WorkEffortType.iid(data[:work_effort_type])
          else
            work_effort.work_effort_type = WorkEffortType.iid(data[:work_effort_type][:internal_identifier])
          end
        end

        if data[:biz_txn_event_id].present?
          work_effort.biz_txn_events << BizTxnEvent.find(data[:biz_txn_event_id])
        end

        work_effort.created_by_party = current_user.party

        work_effort.save!

        # set dba_org
        work_effort.add_party_with_role(current_user.party.dba_organization, RoleType.iid('dba_org'))

        # if scope by user set the current user relationship
        # scope by user if present
        if params[:scope_by_user].present? and params[:scope_by_user].to_bool
          work_resource_role_type = RoleType.find_or_create("work_resource", "Work Resource", RoleType.iid("application_composer"))
          WorkEffortPartyAssignment.create(work_effort: work_effort,
                                           role_type: work_resource_role_type,
                                           party: current_user.party)
        end

        if data[:parent_id].present? and data[:parent_id] != 0
          parent = WorkEffort.find(data[:parent_id])
          work_effort.move_to_child_of(parent)
          work_effort.reload
        end

        work_effort
      end

      def update_work_effort(data)
        work_effort = WorkEffort.find(data[:id])

        if data[:description].present?
          work_effort.description = data[:description].strip
        end

        if data[:start_at].present?
          work_effort.start_at = Time.parse(data[:start_at])
        end

        if data[:end_at].present?
          work_effort.end_at = Time.parse(data[:end_at])
        end

        if data[:percent_done].present?
          work_effort.percent_done = data[:percent_done]
        end

        if data[:duration].present?
          work_effort.duration = data[:duration]
        end

        if data[:duration_unit].present?
          work_effort.duration_unit = data[:duration_unit]
        end

        if data[:effort].present?
          work_effort.effort = data[:effort]
        end

        if data[:effort_unit].present?
          work_effort.effort_unit = data[:effort_unit]
        end

        if data[:comments].present?
          work_effort.comments = data[:comments].strip
        end

        if data[:sequence].present?
          work_effort.sequence = data[:sequence]
        end

        if data[:status].present?
          if data[:status].is_a? String
            work_effort.current_status = TrackedStatusType.iid(data[:status])
          else
            work_effort.current_status = TrackedStatusType.iid(data[:status][:tracked_status_type][:internal_identifier])
          end
        end

        if data[:work_effort_type].present?
          if data[:work_effort_type].is_a? String
            work_effort.work_effort_type = WorkEffortType.iid(data[:work_effort_type])
          else
            work_effort.work_effort_type = WorkEffortType.iid(data[:work_effort_type][:internal_identifier])
          end
        end

        work_effort.updated_by_party = current_user.party

        work_effort.save!

        # if there is a parent move the node under that parent
        if data[:parent_id].present? and data[:parent_id] != 0
          parent = WorkEffort.find(data[:parent_id])
          work_effort.move_to_child_of(parent)

          # if there is no parent then move to root
        elsif data[:parent_id] == 'root'
          work_effort.move_to_root
        end

        work_effort
      end

    end # WorkEffortsController
  end # V1
end # API
