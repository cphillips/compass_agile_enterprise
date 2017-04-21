module API
  module V1
    class BizTxnPartyRolesController < BaseController

=begin

 @api {get} /api/v1/biz_txn_party_roles Index
 @apiVersion 1.0.0
 @apiName GetBizTxnPartyRoles
 @apiGroup BizTxnPartyRole

 @apiParam {Integer} party_id Id of party to get BizTxnPartyRoles for

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Number} total_count Total count of records based on any filters applied
 @apiSuccess {Array} biz_txn_party_roles List of BizTxnPartyRole records
 @apiSuccess {Number} biz_txn_party_roles.id Id of BizTxnPartyRole

=end

      def index
        if params[:party_id]
          sort = nil
          dir = nil
          limit = nil
          start = nil

          unless params[:sort].blank?
            sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
            sort = sort_hash[:property] || 'id'
            dir = sort_hash[:direction] || 'ASC'
            limit = params[:limit] || 25
            start = params[:start] || 0
          end

          biz_txn_party_roles = BizTxnPartyRoles.where(party: params[:party_id])

          if sort and dir
            biz_txn_party_roles = biz_txn_party_roles.order("#{sort} #{dir}")
          end

          total_count = biz_txn_party_roles.count

          if start and limit
            biz_txn_party_roles = biz_txn_party_roles.offset(start).limit(limit)
          end

          render :json => {success: true, total_count: total_count, biz_txn_party_roles: biz_txn_party_roles.collect(&:to_data_hash)}
        else
          render :json => {success: false, message: 'Party Id is required'}
        end
      end

=begin

 @api {post} /api/v1/biz_txn_party_roles Create
 @apiVersion 1.0.0
 @apiName CreateBizTxnPartyRoles
 @apiGroup BizTxnPartyRole

 @apiParam {Integer} biz_txn_event_id Id of BizTxnEvent
 @apiParam {Integer} [party_id] Id of party to create BizTxnPartyRoles for, if none is passed it will use current_user.party
 @apiParam {String} [biz_txn_party_role_types] Comma delimitted list of Internal Identifiers of BizTxnPartyRoleTypes

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Array} biz_txn_party_roles newly created BizTxnPartyRole records
 @apiSuccess {Number} biz_txn_party_role.id Id of BizTxnPartyRole

=end

      def create
        begin
          ActiveRecord::Base.connection.transaction do
            party_id = params[:party_id] || current_user.party.id

            biz_txn_party_roles = []

            if params[:biz_txn_party_role_types]
              biz_txn_party_role_types = params[:biz_txn_party_role_types].split(',')

              biz_txn_party_role_types.each do |biz_txn_party_role_type|
                biz_txn_party_role_type = BizTxnPartyRoleType.iid(biz_txn_party_role_type)

                biz_txn_party_role = BizTxnPartyRole.where(party_id: party_id,
                                                           biz_txn_event_id: params[:biz_txn_event_id],
                                                           biz_txn_party_role_type_id: biz_txn_party_role_type.id).first
                if biz_txn_party_role
                  biz_txn_party_roles << biz_txn_party_role
                else
                  biz_txn_party_roles << BizTxnPartyRole.create(party_id: party_id,
                                                                biz_txn_event_id: params[:biz_txn_event_id],
                                                                biz_txn_party_role_type_id: biz_txn_party_role_type.id)
                end
              end

              render json: {success: true, biz_txn_party_roles: biz_txn_party_roles}
            else
              biz_txn_party_role = BizTxnPartyRole.where(party_id: party_id, biz_txn_event_id: params[:biz_txn_event_id]).first
              if biz_txn_party_role
                biz_txn_party_roles << biz_txn_party_role
              else
                biz_txn_party_roles << BizTxnPartyRole.create(party_id: party_id, biz_txn_event_id: params[:biz_txn_event_id])
              end
            end

            render json: {success: true, biz_txn_party_roles: biz_txn_party_roles.collect(&:to_data_hash)}
          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error creating BizTxnPartyRole'}
        end
      end

=begin

 @api {post} /api/v1/biz_txn_party_roles/:id Destroy
 @apiVersion 1.0.0
 @apiName DestroyBizTxnPartyRoles
 @apiGroup BizTxnPartyRole

 @apiSuccess {Boolean} success True if the request was successful

=end

      def destroy
        biz_txn_party_role = BizTxnPartyRole.find(params[:id])
        biz_txn_party_role.destroy

        render json: {success: true}
      end

    end # BizTxnPartyRolesController
  end # V1
end # API
