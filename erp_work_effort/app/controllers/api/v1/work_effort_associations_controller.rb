module API
  module V1
    class WorkEffortAssociationsController < BaseController

=begin

 @api {get} /api/v1/work_effort_associations Index
 @apiVersion 1.0.0
 @apiName GetWorkEffortAssociations
 @apiGroup WorkEffortAssociation

 @apiParam {Number} [project_id] Project ID to scope by

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Array} work_effort_associations List of WorkEffortAssociations
 @apiSuccess {Number} work_effort_associations.work_effort_id_from Id of from WorkEffort
 @apiSuccess {Decimal} work_effort_associations.work_effort_id_to Id of to WorkEffort
 @apiSuccess {Object} work_effort_associations.work_effort_association_type WorkEffortAssociationType
 @apiSuccess {DateTime} work_effort_associations.created_at When the WorkEffortAssociation was created
 @apiSuccess {DateTime} work_effort_associations.updated_at When the WorkEffortAssociation was updated

=end

      def index
        work_effort_associations = WorkEffortAssociation

        if params[:project_id]
          work_effort_associations = work_effort_associations.joins('inner join work_efforts on work_efforts.id = work_effort_associations.work_effort_id_to')
                                         .where('work_efforts.project_id = ?', params[:project_id])
        else
          # scope by dba organization
          work_effort_associations = work_effort_associations.joins('inner join work_efforts on work_efforts.id = work_effort_associations.work_effort_id_to')
                                         .joins("inner join entity_party_roles on entity_party_roles.entity_record_type = 'WorkEffort' and entity_party_roles.entity_record_id = work_efforts.id")
                                         .where('entity_party_roles.party_id = ? and entity_party_roles.role_type_id = ?', current_user.party.dba_organization.id, RoleType.iid('dba_org').id)
        end

        render :json => {success: true, work_effort_associations: work_effort_associations.all.map { |work_effort| work_effort.to_data_hash }}
      end

=begin

 @api {get} /api/v1/work_effort_association/:id Show
 @apiVersion 1.0.0
 @apiName ShowWorkEffortAssociation
 @apiGroup WorkEffortAssociation

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Object} work_effort_association WorkEffortAssociation
 @apiSuccess {Number} work_effort_association.work_effort_id_from Id of from WorkEffort
 @apiSuccess {Decimal} work_effort_association.work_effort_id_to Id of to WorkEffort
 @apiSuccess {Object} work_effort_association.work_effort_association_type WorkEffortAssociationType
 @apiSuccess {DateTime} work_effort_association.created_at When the WorkEffortAssociation was created
 @apiSuccess {DateTime} work_effort_association.updated_at When the WorkEffortAssociation was updated

=end

      def show
        render :json => {success: true, work_effort_association: WorkEffortAssociation.find(params[:id]).to_data_hash}
      end

=begin

 @api {post} /api/v1/work_effort_association Create
 @apiVersion 1.0.0
 @apiName CreateWorkEffortAssociation
 @apiGroup WorkEffortAssociation

 @apiParam {Number} work_effort_id_from ID of from WorkEffort
 @apiParam {Number} work_effort_id_to ID of to WorkEffort
 @apiParam {String} work_effort_association_type Internal Identifier of WorkEffortAssociationType

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Object} work_effort_association WorkEffortAssociation
 @apiSuccess {Number} work_effort_association.work_effort_id_from Id of from WorkEffort
 @apiSuccess {Decimal} work_effort_association.work_effort_id_to Id of to WorkEffort
 @apiSuccess {Object} work_effort_association.work_effort_association_type WorkEffortAssociationType
 @apiSuccess {DateTime} work_effort_association.created_at When the WorkEffortAssociation was created
 @apiSuccess {DateTime} work_effort_association.updated_at When the WorkEffortAssociation was updated

=end

      def create
        begin
          ActiveRecord::Base.connection.transaction do

            work_effort_association_type = params['work_effort_association_type.external_identifier'] || params['work_effort_association_type']

            work_effort_association = WorkEffortAssociation.new
            work_effort_association.work_effort_id_from = params[:work_effort_id_from]
            work_effort_association.work_effort_id_to = params[:work_effort_id_to]
            work_effort_association.work_effort_association_type = WorkEffortAssociationType.where('external_identifier = ?', params['work_effort_association_type.external_identifier'].to_s).first

            work_effort_association.save!

            render :json => {success: true, work_effort_association: work_effort_association.to_data_hash}

          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error creating Work Effort Association'}
        end
      end

=begin

 @api {put} /api/v1/work_effort_association/:id Update
 @apiVersion 1.0.0
 @apiName UpdateWorkEffortAssociation
 @apiGroup WorkEffortAssociation

 @apiParam {Number} work_effort_id_from ID of from WorkEffort
 @apiParam {Number} work_effort_id_to ID of to WorkEffort
 @apiParam {String} work_effort_association_type Internal Identifier of WorkEffortAssociationType

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Object} work_effort_association WorkEffortAssociation
 @apiSuccess {Number} work_effort_association.work_effort_id_from Id of from WorkEffort
 @apiSuccess {Decimal} work_effort_association.work_effort_id_to Id of to WorkEffort
 @apiSuccess {Object} work_effort_association.work_effort_association_type WorkEffortAssociationType
 @apiSuccess {DateTime} work_effort_association.created_at When the WorkEffortAssociation was created
 @apiSuccess {DateTime} work_effort_association.updated_at When the WorkEffortAssociation was updated

=end

      def update
        begin
          ActiveRecord::Base.connection.transaction do

            work_effort_association_type = params['work_effort_association_type.external_identifier'] || params['work_effort_association_type']

            work_effort_association = WorkEffortAssociation.find(params[:id])
            work_effort_association.work_effort_id_from = params[:work_effort_id_from]
            work_effort_association.work_effort_id_to = params[:work_effort_id_to]
            work_effort_association.work_effort_association_type = WorkEffortAssociationType.where('external_identifier = ?', params[:work_effort_association_type_external_id].to_s).first

            work_effort_association.save!

            render :json => {success: true, work_effort_association: work_effort_association.to_data_hash}

          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error updating Work Effort Association'}
        end
      end

=begin

 @api {delete} /api/v1/work_effort_association/:id Delete
 @apiVersion 1.0.0
 @apiName DeleteWorkEffortAssociation
 @apiGroup WorkEffortAssociation

 @apiSuccess {Boolean} success True if the request was successful

=end

      def destroy
        work_effort_association = WorkEffortAssociation.find(params[:id])

        begin
          ActiveRecord::Base.connection.transaction do

            render json: {success: work_effort_association.destroy}

          end
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error destroying Work Effort Association'}
        end
      end

    end # WorkEffortAssociationsController
  end # V1
end # API
