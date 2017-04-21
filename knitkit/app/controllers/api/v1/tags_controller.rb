module API
  module V1
    class TagsController < BaseController

      def index
        tags = ActsAsTaggableOn::Tag

        unless params[:query_filter].blank?
          query_filter = Hash.symbolize_keys(JSON.parse(params[:query_filter]))

          tags = ActsAsTaggableOn::Tag.where(ActsAsTaggableOn::Tag.arel_table[:name].matches('%' + query_filter[:name] + '%'))
        end

        render json: {
          success: true,
          total_count: tags.count,
          tags: tags.all.collect{|tag| tag.to_hash(only: [:id, :name])}
        }
      end

    end # TagsController
  end # V1
end # API
