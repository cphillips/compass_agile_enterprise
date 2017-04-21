module API
  module V1
    class WebsitesController < BaseController

      def index
        render json: {
                   success: true,
                   websites: Website.scope_by_dba_organization(current_user.party.dba_organization).all.collect { |w| w.to_data_hash }
               }
      end

    end # WebsitesController
  end # V1
end # API