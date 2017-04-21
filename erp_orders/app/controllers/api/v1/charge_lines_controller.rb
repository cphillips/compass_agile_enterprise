module API
  module V1
    class ChargeLinesController < BaseController

=begin

  @api {get} /api/v1/charge_lines Index
  @apiVersion 1.0.0
  @apiName GetChargelines
  @apiGroup ChargeLine
 
  @apiParam {String} [type] the type of charges to filter by.  Should of an internal identifier for a ChargeType	

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} charge_lines ChargeLine records

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

        charge_lines = ChargeLine

        if params[:order_txn_id]
          charge_lines = charge_lines.where('charged_item_type = ? and charged_item_id = ?', 'OrderTxn', params[:order_txn_id])

          if params[:type]
            charge_lines = charge_lines.joins(:charge_type).where(charge_types: {internal_identifier: params[:type]})
          end

          if sort and dir
            charge_lines = charge_lines.order("#{sort} #{dir}")
          end

          total_count = charge_lines.count

          if start and limit
            charge_lines = charge_lines.offset(start).limit(limit)
          end

          render :json => {success: true,
                           total_count: total_count,
                           charge_lines: charge_lines.collect { |charge_line| charge_line.to_data_hash }}
        else
          render json: {success: false, message: 'An order_txn_id must be passed'}
        end
      end

=begin

  @api {get} /api/v1/charge_lines Post
  @apiVersion 1.0.0
  @apiName CreateChargeline
  @apiGroup ChargeLine
 
  @apiParam {Decimal} amount the amount of the charge
  @apiParam {String} desciption the description of the charge
  @apiParam {String} [type] the type of charges to filter by.  Should of an internal identifier for a ChargeType	

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} charge_line Newly created ChargeLine

=end

      def create
        begin
          ActiveRecord::Base.connection.transaction do

            if params[:order_txn_id]

              order_txn = OrderTxn.find(params[:order_txn_id])

              # add shipping charges
              money = Money.create(
                description: params[:description],
                amount: params['amount'],
                currency: Currency.usd
              )

              charge_line = order_txn.charge_lines.create(
                money_id: money.id,
                description: params[:description]
              )

              if params[:type]
                charge_line.charge_type = ChargeType.find_by_internal_identifier(params[:type])
                charge_line.save!
              end

              render :json => {success: true, charge_line: charge_line.to_data_hash}

            else
              render json: {success: false, message: 'An order_txn_id must be passed'}
            end
          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error creating ChargeLine'}
        end
      end

=begin

  @api {get} /api/v1/charge_lines Put
  @apiVersion 1.0.0
  @apiName UpdateChargeline
  @apiGroup ChargeLine
 
  @apiParam {Decimal} amount the amount of the charge
  @apiParam {String} desciption the description of the charge
  @apiParam {String} [type] the type of charges to filter by.  Should of an internal identifier for a ChargeType	

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Array} charge_line updated ChargeLine

=end

      def update
        begin
          ActiveRecord::Base.connection.transaction do

            charge_line = ChargeLine.find(params[:id])

            if params[:amount].present?
              charge_line.money.amount = params[:amount]
            end

            if params[:description].present?
              charge_line.description = params[:description]
              charge_line.money.description = params[:description]
            end

            if params[:type]
              charge_line.charge_type = ChargeType.find_by_internal_identifier(params[:type])
            end

            charge_line.money.save!
            charge_line.save!

            render :json => {success: true, charge_line: charge_line.to_data_hash}

          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error creating ChargeLine'}
        end
      end

    end # ChargeLinesController
  end # V1
end # API
