module API
  module V1
    class OrderLineItemsController < BaseController

=begin

  @api {get} /api/v1/order_line_items Index
  @apiVersion 1.0.0
  @apiName GetOrderLineItems
  @apiGroup OrderLineItem

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} order_line_items OrderLineItem records

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
          limit = params[:limit] || 25
          start = params[:start] || 0
        end

        #query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys
        context = params[:context].blank? ? {} : JSON.parse(params[:context]).symbolize_keys

        # hook method to apply any scopes passed via parameters to this api
        #order_line_items = OrderLine_Items.apply_filters(query_filter)
        order_line_items = OrderLineItem

        if params[:order_txn_id]
          order_line_items = order_line_items.where('order_txn_id = ?', params[:order_txn_id])

          if sort and dir
            order_line_items = order_txns.order("#{sort} #{dir}")
          end

          total_count = order_line_items.count

          if start and limit
            order_line_items = order_line_items.offset(start).limit(limit)
          end

          if context[:view]
            if context[:view] == 'mobile'
              render :json => {success: true,
                               total_count: total_count,
                               order_line_items: order_line_items.collect { |order_line_item| order_line_item.to_mobile_hash }}
            end
          else
            render :json => {success: true,
                             total_count: total_count,
                             order_line_items: order_line_items.collect { |order_line_item| order_line_item.to_data_hash }}
          end
        else
          render json: {success: false, message: 'An Order Txn Id must be passed'}
        end

      end

    end # OrderLineItemsController
  end # V1
end # API