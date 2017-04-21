module API
  module V1
    class SelectedProductOptionsController < BaseController

=begin

  @api {get} /api/v1/selected_product_options Index
  @apiVersion 1.0.0
  @apiName GetSelectedProductOptions
  @apiGroup SelectedProductOption

  @apiParam {String} selected_record_type Type of Selected Record to scope by
  @apiParam {Integer} selected_record_id Id of Selected Record to scope by

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} selected_product_options SelectedProductOption records

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

        if params[:sort] && params[:offset]
          limit = params[:limit] || 25
          start = params[:start] || 0
        end

        if params[:selected_record_type] && params[:selected_record_id]
          selected_product_options = SelectedProductOption.where('selected_option_record_type = ? and selected_option_record_id = ?', params[:selected_record_type], params[:selected_record_id])
        else
          raise 'selected_record_type and selected_record_id are required'
        end

        if sort and dir
          selected_product_options = selected_product_options.order("#{sort} #{dir}")
        end

        total_count = selected_product_options.count

        if start and limit
          selected_product_options = selected_product_options.offset(start).limit(limit)
        end

        render :json => {success: true,
                         total_count: total_count,
                         selected_product_options: selected_product_options.collect(&:to_data_hash)}

      end

    end # SelectedProductOptionsController
  end # V1
end # API
