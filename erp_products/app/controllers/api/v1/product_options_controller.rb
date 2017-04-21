module API
  module V1
    class ProductOptionsController < BaseController

=begin

  @api {get} /api/v1/product_options Index
  @apiVersion 1.0.0
  @apiName GetProductOptions
  @apiGroup ProductOption

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} product_options ProductOption records

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

        product_options = ProductOption.joins(:product_option_type).where(product_option_types: {tenant_id: current_user.party.dba_organization})

        if params[:product_option_type_id]
          product_options = product_options.where(product_option_type_id: params[:product_option_type_id])
        end

        if sort and dir
          product_options = product_options.order("#{sort} #{dir}")
        end

        total_count = product_options.count

        if start and limit
          product_options = product_options.offset(start).limit(limit)
        end

        render :json => {success: true,
                         total_count: total_count,
                         product_options: product_options.collect(&:to_data_hash)}

      end

=begin

  @api {get} /api/v1/product_options/:id Show
  @apiVersion 1.0.0
  @apiName GetProductOption
  @apiGroup ProductOption

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} product_option ProductOption record

=end

      def show
        product_option = ProductOption.find(params[:id])

        render :json => {success: true,
                         product_option: product_option.to_data_hash}
      end

=begin

  @api {post} /api/v1/product_options Create
  @apiVersion 1.0.0
  @apiName CreateProductOption
  @apiGroup ProductOption

  @apiParam {Integer} product_option_type Id of ProductOptionType
  @apiParam {String} description Description
  @apiParam {String} internal_identifier Internal Identifier

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} product_option ProductOption record

=end

      def create
        begin
          ActiveRecord::Base.transaction do
            product_option = new_product_option

            render :json => {success: true,
                             product_option: product_option.to_data_hash}
          end

        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}

        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: 'Could not create product option'}
        end
      end

=begin

  @api {put} /api/v1/product_options/:id Update
  @apiVersion 1.0.0
  @apiName UpdateProductOption
  @apiGroup ProductOption
  
  @apiParam {String} [description] Description
  @apiParam {String} [internal_identifier] Internal Identifier

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} product_option ProductOption record

=end

      def update
        begin
          ActiveRecord::Base.transaction do
            product_option = update_product_option

            render :json => {success: true,
                             product_option: product_option.to_data_hash}
          end

        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}

        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: 'Could not update product option'}
        end
      end

=begin

  @api {delete} /api/v1/product_options/:id Delete
  @apiVersion 1.0.0
  @apiName DeleteProductOption
  @apiGroup ProductOption

  @apiSuccess {Boolean} success True if the request was successful

=end

      def destroy
        ProductOption.find(params[:id]).destroy

        render :json => {:success => true}
      end

      private

      def new_product_option
        product_option = ProductOption.new
        product_option.description = params[:description]
        product_option.internal_identifier = params[:internal_identifier]
        product_option.is_default = params[:is_default]

        product_option.created_by_party = current_user.party

        product_option.product_option_type_id = params[:product_option_type_id]

        product_option.save!

        product_option
      end

      def update_product_option
        product_option = ProductOption.find(params[:id])

        if params[:description].present?
          product_option.description = params[:description]
        end

        if params[:internal_identifier].present?
          product_option.internal_identifier = params[:internal_identifier]
        end

        if params[:is_default].present?
          product_option.is_default = params[:is_default]
        end

        product_option.updated_by_party = current_user.party

        product_option.save!

        product_option
      end

    end # ProductOptionsController
  end # V1
end # API
