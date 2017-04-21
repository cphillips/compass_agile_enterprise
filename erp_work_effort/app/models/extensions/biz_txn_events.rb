module API
  module V1
    module Extensions
      module BizTxnEventFilters

        # Filter records
        #
        # @param filters [Hash] a hash of filters to be applied,
        # @param statement [ActiveRecord::Relation] the query being built
        # @return [ActiveRecord::Relation] the query being built
        def apply_filters(filters, statement=nil)
          biz_txn_events = super(filters, statement)

          if filters[:work_effort_id]
            biz_txn_events = biz_txn_events.joins(:work_effort_biz_txn_events)
                                 .where('work_effort_biz_txn_events.work_effort_id' => filters[:work_effort_id])
          end

          biz_txn_events
        end

      end # BizTxnEventFilters
    end # Extensions
  end # V1
end # API

BizTxnEvent.singleton_class.prepend API::V1::Extensions::BizTxnEventFilters

BizTxnEvent.class_eval do

  ## What WorkEfforts have been related to this BizTxnEvent
  has_many :work_effort_biz_txn_events, :dependent => :destroy
  has_many :work_efforts, :through => :work_effort_biz_txn_events

end
