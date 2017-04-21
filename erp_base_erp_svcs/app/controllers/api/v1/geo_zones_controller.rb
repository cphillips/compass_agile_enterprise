module API
  module V1
    class GeoZonesController < BaseController

      skip_before_filter :require_login, :only => :index

      def index
        GeoZone.include_root_in_json = false

        if params[:geo_country_iso_code_2].present?
          geo_country = GeoCountry.find_by_iso_code_2(params[:geo_country_iso_code_2])
          if geo_country
            render json: {success: true, geo_zones: GeoZone.where('geo_country_id = ?', geo_country.id).all}
          else
            render json: {success: false, message: 'Invalid Geo Country'}
          end

        else
          render json: {success: true, geo_zones: GeoZone.all}
        end
      end

    end # GeoZonesController
  end # V1
end # API