module API
  module V1
    class FileAssetsController < BaseController

      def index
        sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
        sort = sort_hash[:property] || 'description'
        dir = sort_hash[:direction] || 'ASC'
        limit = params[:limit] || 25
        start = params[:start] || 0
        query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys

        # apply filters
        file_assets = FileAsset.apply_filters(query_filter)

        # if no file asset holder was passed we need to scope by dba_organization
        if !query_filter[:file_asset_holder_type].present? && !query_filter[:file_asset_holder_id].present?
          file_assets = file_assets.scope_by_dba_org(current_user.party.dba_organization)
        end

        total_count = file_assets.count
        file_assets = file_assets.limit(limit).offset(start)
        file_assets.order("#{sort} #{dir}")

        render json: {success: true,
                      total_count: total_count,
                      file_assets: file_assets.collect { |file| file.to_data_hash }}
      end

      def create
        begin
          ActiveRecord::Base.transaction do
            file_support = ErpTechSvcs::FileSupport::Base.new(:storage => ErpTechSvcs::Config.file_storage)

            record = params[:file_asset_holder_type].constantize.find(params[:file_asset_holder_id])

            file_name = params[:file].original_filename
            data = params[:file].read

            path = File.join(file_support.root, 'file_assets', params[:file_asset_holder_type], params[:file_asset_holder_id], file_name)

            file_asset = record.add_file(data, path)

            if params[:scopes]
              JSON.parse(params[:scopes]).each do |scope|
                file_asset.add_scope(scope['name'], scope['value'])
              end
            end

            render json: {success: true, file_asset: file_asset.to_data_hash}
          end
        rescue StandardError => ex
          logger.error ex.message
          logger.error ex.backtrace.join("\n")

          render json: {success: false, message: "Error creating file_asset"}
        end
      end

      def destroy
        file_asset = FileAsset.find(params[:id])

        file_asset.destroy

        render json: {success: true}
      end

    end # FileAssetsController
  end # V1
end # API
