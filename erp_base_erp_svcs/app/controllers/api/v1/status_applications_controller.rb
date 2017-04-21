module API
  module V1
    class StatusApplicationsController < BaseController

      def index
        statuses = if params[:record_id].present? && params[:record_type].present?

          # if the record acts as BizTxnEvent we need to use BizTxnEvent
          record = params[:record_type].constantize.find(params[:record_id])
          if record.respond_to?(:root_txn)
            record_type = 'BizTxnEvent'
            record_id = record.root_txn.id
          else
            record_type = params[:record_type]
            record_id = params[:record_id]
          end

          StatusApplication.where('status_application_record_id = ? and status_application_record_type = ?',
                                  record_id,
                                  record_type)
          .includes(:tracked_status_type).order('created_at desc').collect do |status|
            status.to_data_hash
          end

        else
          StatusApplication.all.collect { |status| status.to_data_hash }
        end

        render :json => {:success => true, :status_applications => statuses}
      end

      def show
        status_application = StatusApplication.find(params[:id])

        render :json => {:success => true, :status_application => status_application.to_data_hash}
      end

    end # StatusApplicationsController
  end # V1
end # API
