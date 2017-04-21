module API
  module V1
    class BizTxnAcctTypesController < BaseController

      def index
        if !params[:parent].blank?
          parent = nil
          # create parent if it doesn't exist
          # if the parent param is a comma separated string then
          # the parent is nested from left to right
          params[:parent].split(',').each do |parent_iid|
            if parent
              parent = BizTxnAcctType.find_or_create(parent_iid, parent_iid.humanize, parent)
            else
              parent = BizTxnAcctType.find_or_create(parent_iid, parent_iid.humanize)
            end
          end

          respond_to do |format|
            format.tree do
              render :json => {success: true, biz_txn_acct_types: parent.children_to_tree_hash}
            end
            format.json do
              render :json => {success: true, biz_txn_acct_types: BizTxnAcctType.to_all_representation(parent)}
            end
          end

          # if ids are passed look up on the txn types with the ids passed
        elsif params[:ids]
          ids = params[:ids].split(',').compact

          biz_txn_acct_types = []

          ids.each do |id|
            # check if id is a integer if so fine by id
            if id.is_integer?
              biz_txn_acct_type = BizTxnAcctType.find(id)
            else
              biz_txn_acct_type = BizTxnAcctType.iid(id)
            end

            respond_to do |format|
              format.tree do
                data = biz_txn_acct_type.to_hash({
                                                only: [:id, :parent_id, :internal_identifier, :description],
                                                leaf: biz_txn_acct_type.leaf?,
                                                text: biz_txn_acct_type.to_label,
                                                children: []
                                            })

                parent = nil
                biz_txn_acct_types.each do |biz_txn_acct_type_hash|
                  if biz_txn_acct_type_hash[:id] == data[:parent_id]
                    parent = biz_txn_acct_type_hash
                  end
                end

                if parent
                  parent[:children].push(data)
                else
                  biz_txn_acct_types.push(data)
                end
              end
              format.json do
                biz_txn_acct_types.push(biz_txn_acct_type.to_hash(only: [:id, :description, :internal_identifier]))
              end
            end

          end

          render :json => {success: true, biz_txn_acct_types: biz_txn_acct_types}

          # get all txn types
        else

          respond_to do |format|
            format.tree do
              nodes = [].tap do |nodes|
                BizTxnAcctType.roots.each do |root|
                  nodes.push(root.to_tree_hash)
                end
              end

              render :json => {success: true, biz_txn_acct_types: nodes}
            end
            format.json do
              render :json => {success: true, biz_txn_acct_types: BizTxnAcctType.to_all_representation}
            end
          end

        end

      end

      def create
        description = params[:description].strip

        begin

          ActiveRecord::Base.transaction do
            biz_txn_acct_type = BizTxnAcctType.create(description: description, internal_identifier: description.to_iid)

            if !params[:parent].blank? and params[:parent] != 'No Parent'
              parent = BizTxnAcctType.iid(params[:parent])
              biz_txn_acct_type.move_to_child_of(parent)
            elsif !params[:default_parent].blank?
              parent = BizTxnAcctType.iid(params[:default_parent])
              biz_txn_acct_type.move_to_child_of(parent)
            end

            render :json => {success: true, biz_txn_acct_type: biz_txn_acct_type.to_hash(only: [:id, :description, :internal_identifier])}
          end

        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors.full_messages

          {:success => false, :message => invalid.record.errors.full_messages.join('</br>')}
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          {:success => false, :message => "Error creating record"}
        end
      end

    end # BizTxnAcctTypesController
  end # V1
end # API