module API
  module V1
    class WorkEffortTypesController < BaseController

=begin

 @api {get} /api/v1/work_effort_types Index
 @apiVersion 1.0.0
 @apiName GetWorkEffortTypes
 @apiGroup WorkEffortType

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Array} work_effort_types List of WorkEffortTypes
 @apiSuccess {Number} work_effort_types.id Id of WorkEffortType
 @apiSuccess {String} work_effort_types.description Description of WorkEffortType
 @apiSuccess {String} work_effort_types.internal_identifier Internal Identifier of WorkEffortType
 @apiSuccess {DateTime} work_effort_types.created_at When the WorkEffortType was created
 @apiSuccess {DateTime} work_effort_types.updated_at When the WorkEffortType was updated

=end

      def index
        if !params[:parent].blank?
          parent = nil
          # create parent if it doesn't exist
          # if the parent param is a comma separated string then
          # the parent is nested from left to right
          params[:parent].split(',').each do |parent_iid|
            if parent
              parent = WorkEffortType.find_or_create(parent_iid, parent_iid.humanize, parent)
            else
              parent = WorkEffortType.find_or_create(parent_iid, parent_iid.humanize)
            end
          end

          respond_to do |format|
            format.tree do
              render :json => {success: true, work_effort_types: parent.children_to_tree_hash}
            end
            format.json do
              render :json => {success: true, work_effort_types: WorkEffortType.to_all_representation(parent)}
            end
          end

          # if ids are passed look up on the txn types with the ids passed
        elsif params[:ids]
          ids = params[:ids].split(',').compact

          work_effort_types = []

          ids.each do |id|
            # check if id is a integer if so fine by id
            if id.is_integer?
              work_effort_type = WorkEffortType.find(id)
            else
              work_effort_type = WorkEffortType.iid(id)
            end

            respond_to do |format|
              format.tree do
                data = work_effort_type.to_hash({
                                                only: [:id, :parent_id, :internal_identifier, :description],
                                                leaf: work_effort_type.leaf?,
                                                text: work_effort_type.to_label,
                                                children: []
                                            })

                parent = nil
                work_effort_types.each do |work_effort_type_hash|
                  if work_effort_type_hash[:id] == data[:parent_id]
                    parent = work_effort_type_hash
                  end
                end

                if parent
                  parent[:children].push(data)
                else
                  work_effort_types.push(data)
                end
              end
              format.json do
                work_effort_types.push(work_effort_type.to_hash(only: [:id, :description, :internal_identifier]))
              end
            end

          end

          render :json => {success: true, work_effort_types: work_effort_types}

          # get all txn types
        else

          respond_to do |format|
            format.tree do
              nodes = [].tap do |nodes|
                WorkEffortType.roots.each do |root|
                  nodes.push(root.to_tree_hash)
                end
              end

              render :json => {success: true, work_effort_types: nodes}
            end
            format.json do
              render :json => {success: true, work_effort_types: WorkEffortType.to_all_representation}
            end
          end

        end
      end

=begin

 @api {get} /api/v1/work_effort_types/:id Show
 @apiVersion 1.0.0
 @apiName ShowWorkEffortTypes
 @apiGroup WorkEffortType

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Array} work_effort_type WorkEffortType
 @apiSuccess {Number} work_effort_type.id Id of WorkEffortType
 @apiSuccess {String} work_effort_type.description Description of WorkEffortType
 @apiSuccess {String} work_effort_type.internal_identifier Internal Identifier of WorkEffortType
 @apiSuccess {DateTime} work_effort_type.created_at When the WorkEffortType was created
 @apiSuccess {DateTime} work_effort_type.updated_at When the WorkEffortType was updated

=end

      def show
        work_effort_type = WorkEffortType.find(params[:id])

        render :json => {success: true, work_effort_type: [work_effort_type.to_data_hash]}
      end

      def create
        description = params[:description].strip

        ActiveRecord::Base.transaction do
          work_effort_type = WorkEffortType.create(description: description, internal_identifier: description.to_iid)

          if !params[:parent].blank? and params[:parent] != 'No Parent'
            parent = WorkEffortType.iid(params[:parent])
            work_effort_type.move_to_child_of(parent)
          elsif !params[:default_parent].blank?
            parent = WorkEffortType.iid(params[:default_parent])
            work_effort_type.move_to_child_of(parent)
          end

          render :json => {success: true, work_effort_type: work_effort_type.to_hash(only: [:id, :description, :internal_identifier])}
        end
      end

    end # WorkEffortTypeController
  end # V1
end # API