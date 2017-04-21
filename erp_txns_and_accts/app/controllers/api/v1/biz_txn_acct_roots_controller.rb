module API
  module V1
    class BizTxnAcctRootsController < BaseController

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
        biz_txn_acct_roots = BizTxnAcctRoot.apply_filters(query_filter)

        # scope by dba_organizations if there are no parties passed as filters
        dba_organizations = [current_user.party.dba_organization]
        dba_organizations = dba_organizations.concat(current_user.party.dba_organization.child_dba_organizations)
        biz_txn_acct_roots = biz_txn_acct_roots.scope_by_dba_organization(dba_organizations)

        respond_to do |format|
          format.json do

            if sort and dir
              biz_txn_acct_roots = biz_txn_acct_roots.order("#{sort} #{dir}")
            end

            total_count = biz_txn_acct_roots.count

            if start and limit
              biz_txn_acct_roots = biz_txn_acct_roots.offset(start).limit(limit)
            end

            render :json => {success: true,
                             total_count: total_count,
                             biz_txn_acct_roots: biz_txn_acct_roots.collect { |item| item.to_data_hash }}
          end
          format.tree do
            if params[:parent_id]
              render :json => {success: true,
                               biz_txn_acct_roots: BizTxnAcctRoot.find(params[:parent_id]).children_to_tree_hash}
            else
              nodes = [].tap do |nodes|
                biz_txn_acct_roots.roots.each do |root|
                  nodes.push(root.to_tree_hash)
                end
              end

              render :json => {success: true,
                               biz_txn_acct_roots: nodes}
            end

          end
          format.all_representation do
            render :json => {success: true,
                             biz_txn_acct_roots: BizTxnAcctRoot.to_all_representation(nil, [], 0, biz_txn_acct_roots.roots)}

          end
        end
      end

      def create
        description = params[:description].strip
        external_identifier = params[:external_identifier].strip

        begin
          ActiveRecord::Base.transaction do
            biz_txn_acct_root = BizTxnAcctRoot.create(description: description,
                                                      internal_identifier: description.to_iid,
                                                      external_identifier: external_identifier)

            if !params[:parent].blank? and params[:parent] != 'No Parent'
              parent = BizTxnAcctRoot.iid(params[:parent])
              biz_txn_acct_root.move_to_child_of(parent)
            elsif !params[:default_parent].blank?
              parent = BizTxnAcctRoot.iid(params[:default_parent])
              biz_txn_acct_root.move_to_child_of(parent)
            end

            if params[:biz_txn_acct_type_iid]
              biz_txn_acct_root.biz_txn_acct_type = BizTxnAcctType.iid(params[:biz_txn_acct_type_iid])
            end

            BizTxnAcctPartyRole.create(biz_txn_acct_root: biz_txn_acct_root,
                                       party: current_user.party.dba_organization,
                                       biz_txn_acct_pty_rtype: BizTxnAcctPtyRtype.find_or_create('dba_org', 'DBA Organization'))

            biz_txn_acct_root.created_by_party = current_user.party

            biz_txn_acct_root.save!

            render :json => {success: true, biz_txn_type: biz_txn_acct_root.to_data_hash}
          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors.full_messages

          render json: {:success => false, :message => invalid.record.errors.full_messages.join('</br>')}
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {:success => false, :message => "Error creating record"}
        end
      end

    end # BizTxnAcctRootsController
  end # V1
end # API
