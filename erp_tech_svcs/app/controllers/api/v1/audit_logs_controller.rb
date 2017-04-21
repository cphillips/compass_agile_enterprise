module API
  module V1
    class AuditLogsController < BaseController

      def index
        sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
        sort = sort_hash[:property] || 'description'
        dir = sort_hash[:direction] || 'ASC'
        limit = params[:limit] || 25
        start = params[:start] || 0
        query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys

        # if no file asset holder was passed we need to scope by dba_organization
        unless query_filter[:tenant].present?
          query_filter[:tenant] = current_user.dba_organization
        end

        # apply filters
        audit_logs = AuditLog.apply_filters(query_filter)

        total_count = audit_logs.count
        audit_logs = audit_logs.limit(limit).offset(start)
        audit_logs.order("#{sort} #{dir}")

        render json: {success: true,
                      total_count: total_count,
                      file_assets: audit_logs.collect { |audit_log| audit_log.to_data_hash }}
      end

    end # AuditLogsController
  end # V1
end # API