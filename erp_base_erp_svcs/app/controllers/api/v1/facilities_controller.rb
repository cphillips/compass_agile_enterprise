module API
  module V1
    class FacilitiesController < BaseController

=begin

 @api {get} /api/v1/facilities Index
 @apiVersion 1.0.0
 @apiName GetFacilities
 @apiGroup Facility

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Number} total_count Total count of records based on any filters applied
 @apiSuccess {Array} facilities List of Facility records
 @apiSuccess {Number} facilities.id Id of Facility

=end

      def index
        sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
        sort = sort_hash[:property] || 'description'
        dir = sort_hash[:direction] || 'ASC'

        facilities = Facility.by_tenant(current_user.party.dba_organization)

        total_count = facilities.count

        if params[:limit].present?
          facilities = facilities.limit(params[:limit])
        end

        if params[:start].present?
          facilities = facilities.offset(params[:start])
        end

        facilities = facilities.uniq.order("#{sort} #{dir}")

        render :json => {success: true, total_count: total_count, facilities: facilities.all.collect(&:to_data_hash)}
      end

    end # FacilitiesController
  end # V1
end # API
