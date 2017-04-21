module API
  module V1
    class ProductOptionApplicabilitiesController < BaseController

=begin

  @api {get} /api/v1/product_option_applicabilities Index
  @apiVersion 1.0.0
  @apiName GetProductOptionApplicabilities
  @apiGroup ProductOptionApplicability

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} product_option_applicabilities ProductOptionApplicability records

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

        if params[:product_type_id]
          product_option_applicabilities = ProductOptionApplicability.joins("inner join product_types on product_types.id = product_option_applicabilities.optioned_record_id
                                                                             and product_option_applicabilities.optioned_record_type = 'ProductType'")
          .where(product_types: {id: params[:product_type_id]})
        else
          raise 'Product Type Id is required'
        end

        if sort and dir
          product_option_applicabilities = product_option_applicabilities.order("#{sort} #{dir}")
        end

        total_count = product_option_applicabilities.count

        if start and limit
          product_option_applicabilities = product_option_applicabilities.offset(start).limit(limit)
        end

        render :json => {success: true,
                         total_count: total_count,
                         product_option_applicabilities: product_option_applicabilities.collect(&:to_data_hash)}

      end

=begin

  @api {get} /api/v1/product_option_applicabilities/update_positions UpdatePositions
  @apiVersion 1.0.0
  @apiName UpdateProductOptionApplicabilityPositions
  @apiGroup ProductOptionApplicability

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} positions Order that Product Option Applicablities should be in

=end

      def update_positions
        position = 0

        begin
          ActiveRecord::Base.transaction do
            JSON.parse(params[:positions]).each do |id|
              product_option_applicability = ProductOptionApplicability.find(id)
              product_option_applicability.position = position
              product_option_applicability.save!

              position += 1
            end

            render :json => {success: true}
          end
        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}

        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: 'Could not update positions'}
        end
      end

=begin

  @api {get} /api/v1/product_option_applicabilities/:id Show
  @apiVersion 1.0.0
  @apiName GetProductOptionApplicability
  @apiGroup ProductOptionApplicability

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} product_option_applicability ProductOptionApplicability record

=end

      def show
        product_option_applicability = ProductOptionApplicability.find(params[:id])

        render :json => {success: true,
                         product_option_applicability: product_option_applicability.to_data_hash}
      end

=begin

  @api {post} /api/v1/product_option_applicabilities Create
  @apiVersion 1.0.0
  @apiName CreateProductOptionApplicability
  @apiGroup ProductOptionApplicability

  @apiParam {Integer} product_type_id Id of ProductType
  @apiParam {String} description Description
  @apiParam {String} product_option_type_id Id of ProductOptionType
  @apiParam {Boolean} [multi_select] If it should be Multi Select
  @apiParam {Boolean} [required] If it should be required

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} product_option_applicability ProductOptionApplicability record

=end

      def create
        begin
          ActiveRecord::Base.transaction do
            product_option_applicability = ProductOptionApplicability.new

            product_option_applicability.description = params[:description]
            product_option_applicability.product_option_type_id = params[:product_option_type_id]

            if params[:multi_select] === true
              product_option_applicability.multi_select = true
            elsif params[:multi_select] === false
              product_option_applicability.multi_select = false
            end

            if params[:required] === true
              product_option_applicability.required = true
            elsif params[:required] === false
              product_option_applicability.required = false
            end

            if params[:product_type_id]
              product_option_applicability.optioned_record_id = params[:product_type_id]
              product_option_applicability.optioned_record_type = 'ProductType'
            else
              raise 'Product Type Id is required'
            end

            product_option_applicability.created_by_party = current_user.party

            product_option_applicability.save!

            render :json => {success: true,
                             product_option_applicability: product_option_applicability.to_data_hash}
          end

        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}

        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: 'Could not create product option applicability'}
        end
      end

=begin

  @api {put} /api/v1/product_option_applicabilities/:id Update
  @apiVersion 1.0.0
  @apiName UpdateProductOptionApplicability
  @apiGroup ProductOptionApplicability
  
  @apiParam {String} [description] Description
  @apiParam {String} [product_option_type_id] Id of ProductOptionType
  @apiParam {Boolean} [multi_select] If it should be Multi Select
  @apiParam {Boolean} [required] If it should be required

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} product_option_applicability ProductOptionApplicability record

=end

      def update
        begin
          ActiveRecord::Base.transaction do
            product_option_applicability = ProductOptionApplicability.find(params[:id])

            if params[:description].present?
              product_option_applicability.description = params[:description]
            end

            if params[:product_option_type_id].present?
              product_option_applicability.product_option_type_id = params[:product_option_type_id]
            end

            if params[:multi_select] === true
              product_option_applicability.multi_select = true
            elsif params[:multi_select] === false
              product_option_applicability.multi_select = false
            end

            if params[:required] === true
              product_option_applicability.required = true
            elsif params[:required] === false
              product_option_applicability.required = false
            end

            product_option_applicability.updated_by_party = current_user.party

            product_option_applicability.save!

            render :json => {success: true,
                             product_option_applicability: product_option_applicability.to_data_hash}
          end

        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}

        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: 'Could not update product option applicability'}
        end
      end

=begin

  @api {delete} /api/v1/product_option_applicabilities/:id Delete
  @apiVersion 1.0.0
  @apiName DeleteProductOptionApplicability
  @apiGroup ProductOptionApplicability

  @apiSuccess {Boolean} success True if the request was successful

=end

      def destroy
        ProductOptionApplicability.find(params[:id]).destroy

        render :json => {:success => true}
      end

    end # ProductOptionApplicabilitiesController
  end # V1
end # API
