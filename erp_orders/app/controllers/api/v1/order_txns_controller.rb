module API
  module V1
    class OrderTxnsController < BaseController

=begin

  @api {get} /api/v1/order_txns Index
  @apiVersion 1.0.0
  @apiName GetOrderTxn
  @apiGroup OrderTxn

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} order_txns OrderTxn records

=end

      def index
        sort = nil
        dir = nil
        limit = nil
        start = nil

        unless params[:sort].blank?
          sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
          sort = sort_hash[:property] || 'description'
          dir = sort_hash[:direction] || 'ASC'
        end

        if !params[:limit].blank? && !params[:start].blank?
          limit = params[:limit] || 25
          start = params[:start] || 0
        end

        query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys
        context = params[:context].blank? ? {} : JSON.parse(params[:context]).symbolize_keys

        # hook method to apply any scopes passed via parameters to this api
        order_txns = OrderTxn.apply_filters(query_filter)

        # scope by dba_organizations if there are no parties passed as filters
        unless query_filter[:user_id]
          dba_organizations = [current_user.party.dba_organization]
          dba_organizations = dba_organizations.concat(current_user.party.dba_organization.child_dba_organizations)
          order_txns = order_txns.scope_by_dba_organization(dba_organizations)
        end

        if params[:id]
          order_txns = order_txns.where(order_txns: {id: params[:id]})
        end

        if sort and dir
          order_txns = order_txns.order("#{sort} #{dir}")
        else
          order_txns = order_txns.order("id desc")
        end

        total_count = order_txns.count

        if start and limit
          order_txns = order_txns.offset(start).limit(limit)
        end

        if context[:view]
          if context[:view] == 'mobile'
            render :json => {success: true,
                             total_count: total_count,
                             order_txns: order_txns.collect(&:to_data_hash)}
          end
        else
          render :json => {success: true,
                           total_count: total_count,
                           order_txns: order_txns.collect(&:to_data_hash)}
        end

      end

=begin

  @api {get} /api/v1/order_txns/:id Show
  @apiVersion 1.0.0
  @apiName ShowOrderTxn
  @apiGroup OrderTxn

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} order_txn OrderTxn record

=end

      def show
        order_txn = OrderTxn.find(params[:id])

        render :json => {success: true,
                         order_txn: order_txn.to_data_hash}
      end

=begin

  @api {delete} /api/v1/order_txns/:id Delete
  @apiVersion 1.0.0
  @apiName DeleteOrderTxn
  @apiGroup OrderTxn

  @apiSuccess {Boolean} success True if the request was successful

=end

      def destroy
        OrderTxn.find(params[:id]).destroy

        render :json => {:success => true}
      end

=begin

  @api {put} /api/v1/order_txns/:id/update_status UpdateStatus
  @apiVersion 1.0.0
  @apiName UpdateOrdetTxnStatus
  @apiGroup OrderTxn

  @apiParam {String} status Internal identifier of status that should be set

  @apiSuccess {Boolean} success True if the request was successful

=end

      def update_status
        order_txn = OrderTxn.find(params[:id])

        order_txn.current_status = params[:status]

        render :json => {:success => true}
      end

=begin

  @api {get} /api/v1/order_txns/:id/parties Parties
  @apiVersion 1.0.0
  @apiName GetParties
  @apiGroup OrderTxn

  @apiParam {String} role_type Comma separated list of role types
  @apiParam {String} include_phone_number True to include phone numbers for parties

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} parties Parties that were found

=end

      def parties
        order_txn = OrderTxn.find(params[:id])

        parties = Party.joins(biz_txn_party_roles: :biz_txn_party_role_type).where(biz_txn_party_roles: {biz_txn_event_id: order_txn.root_txn.id})

        if params[:role_type]
          parties = parties.where(biz_txn_party_role_types: {internal_identifier: params[:role_type].split(',')})
        end

        render :json => {:success => true, parties: parties.collect{|party| party.to_data_hash(include_phone_number: params[:include_phone_number])}}
      end

=begin
  @api {put} /api/v1/order_txns/:id/related_order_txns RelatedOrders
  @apiVersion 1.0.0
  @apiName RelatedOrderTxns
  @apiGroup OrderTxn

  @apiParam {type} type of order to find

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} order_txns Related OrderTxn records

=end     

      def related_order_txns
        order_txn = OrderTxn.find(params[:id])

        order_txns = OrderTxn.joins(:biz_txn_event).joins('inner join biz_txn_relationships on biz_txn_relationships.txn_event_id_from = biz_txn_events.id')
        .where(biz_txn_relationships: {txn_event_id_to: order_txn.root_txn.id})

        if params[:type]
          order_txns = order_txns.joins(:bix_txn_type).where(biz_txn_types: {internal_identiifer: params[:type]})
        end

        total_count = order_txns.count

        render :json => {success: true,
                         total_count: total_count,
                         order_txns: order_txns.collect(&:to_data_hash)}
      end

    end # OrderTxnsController
  end # V1
end # API
