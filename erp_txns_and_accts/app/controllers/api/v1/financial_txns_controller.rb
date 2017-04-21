module API
  module V1
    class FinancialTxnsController < BaseController

      def index
        sort = nil
        dir = nil
        limit = nil
        start = nil

        unless params[:sort].blank?
          sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
          sort = sort_hash[:property] || 'description'
          dir = sort_hash[:direction] || 'ASC'
          limit = params[:limit] || 25
          start = params[:start] || 0
        end

        query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys

        # hook method to apply any scopes passed via parameters to this api
        financial_txns = FinancialTxn.apply_filters(query_filter)

        # scope by dba_organizations if there are no parties passed as filters
        unless query_filter[:parties]
          dba_organizations = [current_user.party.dba_organization]
          dba_organizations = dba_organizations.concat(current_user.party.dba_organization.child_dba_organizations)
          financial_txns = financial_txns.scope_by_dba_organization(dba_organizations)
        end

        if sort and dir
          financial_txns = financial_txns.order("#{sort} #{dir}")
        end

        total_count = financial_txns.count

        if start and limit
          financial_txns = financial_txns.offset(start).limit(limit)
        end

        render :json => {success: true, total_count: total_count, financial_txns: financial_txns.collect(&:to_data_hash)}
      end

      def show
        financial_txn = FinancialTxn.find(params[:id])

        render :json => {financial_txn: financial_txn.to_data_hash}
      end


    end # BizTxnEvents
  end # V1
end # API