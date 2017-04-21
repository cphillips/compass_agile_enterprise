module API
  module V1
    module Extensions
      module FinancialTxnFilters

        # Filter records
        #
        # @param filters [Hash] a hash of filters to be applied,
        # @param statement [ActiveRecord::Relation] the query being built
        # @return [ActiveRecord::Relation] the query being built
        def apply_filters(filters, statement=nil)
          financial_txns = super(filters, statement)

          if filters[:work_effort_id]
            financial_txns = financial_txns.joins(biz_txn_event: :work_effort_biz_txn_events)
                                 .where('work_effort_biz_txn_events.work_effort_id' => filters[:work_effort_id])
          end

          financial_txns
        end

      end # BizTxnEventFilters
    end # Extensions
  end # V1
end # API

FinancialTxn.singleton_class.prepend API::V1::Extensions::FinancialTxnFilters
