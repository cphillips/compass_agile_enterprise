module API
  module V1
    class AuditLogItemsController < BaseController

      def index
        sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
        sort = sort_hash[:property] || 'description'
        dir = sort_hash[:direction] || 'ASC'
        limit = params[:limit] || 25
        start = params[:start] || 0
        # query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys

        if params[:audit_log_id].present?
          audit_log_items = AuditLogItem.where(audit_log_id: params[:audit_log_id])

          total_count = audit_log_items.count
          audit_log_items = audit_log_items.limit(limit).offset(start)
          audit_log_items.order("#{sort} #{dir}")

          render json: {success: true,
                        total_count: total_count,
                        audit_log_items: audit_log_items.collect { |audit_log_item| audit_log_item.to_data_hash }}

        else
          render json: {success: false,
                        message: 'Audit Log id must be passed'}
        end

      end

    end # AuditLogItemsController
  end # V1
end # API