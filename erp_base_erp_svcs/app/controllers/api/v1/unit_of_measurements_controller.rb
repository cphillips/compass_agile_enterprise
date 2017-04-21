module API
  module V1
    class UnitOfMeasurementsController < BaseController

=begin

 @api {get} /api/v1/unit_of_measurements Index
 @apiVersion 1.0.0
 @apiName GetUnitOfMeasurements
 @apiGroup Unit Of Measurement

 @apiParam {String} [query] Query to search description by

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Number} total_count Total count of records based on any filters applied
 @apiSuccess {Array} unit_of_measurements List of UnitOfMeasurement records
 @apiSuccess {Number} unit_of_measurements.id Id of UnitOfMeasurement

=end

      def index
        statement = UnitOfMeasurement.scope_by_dba_organization(current_user.party.dba_organization)

        if params[:query]
          statement = statement.where(UnitOfMeasurement.arel_table[:description].matches(params[:query] + '%').or(UnitOfMeasurement.arel_table[:internal_identifier].matches(params[:query] + '%')))
        end

        render json: {unit_of_measurements: statement.all.collect(&:to_data_hash)}
      end

    end # UnitOfMeasurementsController
  end # V1
end # API
