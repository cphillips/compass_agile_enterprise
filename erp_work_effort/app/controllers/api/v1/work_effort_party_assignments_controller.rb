module API
  module V1
    class WorkEffortPartyAssignmentsController < BaseController

=begin

 @api {get} /api/v1/work_effort_party_assignments Index
 @apiVersion 1.0.0
 @apiName GetWorkEffortPartyAssignments
 @apiGroup WorkEffortPartyAssignment

 @apiParam {Number} [project_id] Project ID to scope by
 @apiParam {Number} [work_effort_id] WorkEffort ID to scope by

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Number} total_count Total count of records
 @apiSuccess {Array} work_effort_party_assignments List of WorkEffortPartyAssignments
 @apiSuccess {Number} work_effort_party_assignments.id Id of WorkEffortPartyAssignment
 @apiSuccess {Decimal} work_effort_party_assignments.resource_allocation Allocation of resource
 @apiSuccess {Object} work_effort_party_assignments.work_effort WorkEffort allocated for
 @apiSuccess {Object} work_effort_party_assignments.party Party allocated

=end

      def index
        query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys

        work_effort_party_assignments = WorkEffortPartyAssignment

        # apply filters
        work_effort_party_assignments = WorkEffortPartyAssignment.apply_filters(query_filter, work_effort_party_assignments)

        # scope by dba organization
        if query_filter[:parties].blank?
          dba_organizations = [current_user.party.dba_organization]
          dba_organizations = dba_organizations.concat(current_user.party.dba_organization.child_dba_organizations)
          work_effort_party_assignments = work_effort_party_assignments.scope_by_dba_organization(dba_organizations)
        end

        work_effort_party_assignments = work_effort_party_assignments.uniq

        total_count = work_effort_party_assignments.count

        unless params[:limit].blank?
          work_effort_party_assignments = work_effort_party_assignments.limit(params[:limit])
        end

        unless params[:start].blank?
          work_effort_party_assignments = work_effort_party_assignments.offset(params[:start])
        end

        render :json => {
                   success: true,
                   total_count: total_count,
                   work_effort_party_assignments: work_effort_party_assignments.all.collect do |work_effort_party_assignment|
                     work_effort_party_assignment.to_data_hash
                   end
               }
      end

=begin

 @api {post} /api/v1/work_effort_party_assignments Create
 @apiVersion 1.0.0
 @apiName CreateWorkEffortPartyAssignments
 @apiGroup WorkEffortPartyAssignment

 @apiParam {Number} party_id ID of Party
 @apiParam {Number} work_effort_id ID of WorkEffort
 @apiParam {Decimal} resource_allocation Allocation percentage

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Array} work_effort_party_assignment WorkEffortPartyAssignment
 @apiSuccess {Number} work_effort_party_assignment.id Id of WorkEffortPartyAssignment
 @apiSuccess {Decimal} work_effort_party_assignment.resource_allocation Allocation of resource
 @apiSuccess {Object} work_effort_party_assignment.work_effort WorkEffort allocated for
 @apiSuccess {Object} work_effort_party_assignment.party Party allocated

=end

      def create
        begin
          ActiveRecord::Base.connection.transaction do

            work_effort_party_assignment = WorkEffortPartyAssignment.new
            work_effort_party_assignment.party_id = params['party.id'] || params[:party_id]
            work_effort_party_assignment.work_effort_id = params['work_effort.id'] || params[:work_effort_id]
            work_effort_party_assignment.role_type = RoleType.iid('work_resource')
            work_effort_party_assignment.resource_allocation = params[:resource_allocation]

            work_effort_party_assignment.created_by_party = current_user.party

            work_effort_party_assignment.save!

            # if the party assigned is not watching this task then make them a watcher
            current_watcher_relationship = EntityPartyRole.where('entity_record_type = ?
                                                                and entity_record_id = ?
                                                                and party_id = ?',
                                                                 'WorkEffort',
                                                                 work_effort_party_assignment.work_effort_id,
                                                                 work_effort_party_assignment.party_id).first

            unless current_watcher_relationship
              work_effort = work_effort_party_assignment.work_effort
              work_effort.add_party_with_role(work_effort_party_assignment.party, RoleType.iid('watcher'))
            end

            render :json => {success: true,
                             work_effort_party_assignment: work_effort_party_assignment.to_data_hash}

          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error creating WorkEffortPartyAssignment'}
        end
      end

=begin

 @api {put} /api/v1/work_effort_party_assignments/:id Update
 @apiVersion 1.0.0
 @apiName UpdateWorkEffortPartyAssignments
 @apiGroup WorkEffortPartyAssignment

 @apiParam {Number} party_id ID of Party
 @apiParam {Number} work_effort_id ID of WorkEffort
 @apiParam {Decimal} resource_allocation Allocation percentage

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Array} work_effort_party_assignment WorkEffortPartyAssignment
 @apiSuccess {Number} work_effort_party_assignment.id Id of WorkEffortPartyAssignment
 @apiSuccess {Decimal} work_effort_party_assignment.resource_allocation Allocation of resource
 @apiSuccess {Object} work_effort_party_assignment.work_effort WorkEffort allocated for
 @apiSuccess {Object} work_effort_party_assignment.party Party allocated

=end

      def update

        begin
          ActiveRecord::Base.connection.transaction do

            work_effort_party_assignment = WorkEffortPartyAssignment.find(params[:id])
            work_effort_party_assignment.party_id = params['party.id'] || params[:party_id]
            work_effort_party_assignment.work_effort_id = params['work_effort.id'] || params[:work_effort_id]
            work_effort_party_assignment.role_type = RoleType.iid('work_resource')
            work_effort_party_assignment.resource_allocation = params[:resource_allocation]

            work_effort_party_assignment.updated_by_party = current_user.party

            render :json => {success: work_effort_party_assignment.save!,
                             work_effort_party_assignment: work_effort_party_assignment.to_data_hash}

          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error updating WorkEffortPartyAssignment'}
        end

      end

=begin

 @api {delete} /api/v1/work_effort_party_assignments/:id Delete
 @apiVersion 1.0.0
 @apiName DeleteWorkEffortPartyAssignments
 @apiGroup WorkEffortPartyAssignment

 @apiSuccess {Boolean} success True if the request was successful

=end

      def destroy

        work_effort_party_assignment = WorkEffortPartyAssignment.find(params[:id])

        begin
          ActiveRecord::Base.connection.transaction do

            render json: {success: work_effort_party_assignment.destroy}

          end
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error destroying WorkEffortPartyAssignment'}
        end

      end

    end # WorkEffortPartyAssignmentsController
  end # V1
end # API