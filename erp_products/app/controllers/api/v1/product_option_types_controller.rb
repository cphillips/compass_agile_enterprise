module API
  module V1
    class ProductOptionTypesController < BaseController

=begin

  @api {get} /api/v1/product_option_types Index
  @apiVersion 1.0.0
  @apiName GetProductOptionTypes
  @apiGroup ProductOptionType

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} product_options ProductOptionType records

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

        product_option_types = ProductOptionType.by_tenant(current_user.party.dba_organization)

        if params[:id]
          product_option_types.where(id: params[:id])
        end

        if sort and dir
          product_option_types = product_option_types.order("#{sort} #{dir}")
        end

        total_count = product_option_types.count

        if start and limit
          product_option_types = product_option_types.offset(start).limit(limit)
        end

        render :json => {success: true,
                         total_count: total_count,
                         product_option_types: product_option_types.collect(&:to_data_hash)}

      end

    end # ProductOptionTypesController
  end # V1
end # API
