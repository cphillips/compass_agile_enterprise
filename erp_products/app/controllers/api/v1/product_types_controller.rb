module API
  module V1
    class ProductTypesController < BaseController

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

        query_filter = params[:query_filter].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:query_filter]))
        context = params[:context].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:context]))

        if params[:query]
          query_filter[:keyword] = params[:query].strip
        end

        # hook method to apply any scopes passed via parameters to this api
        product_types = ProductType.apply_filters(query_filter)

        # scope by dba_organizations if there are no parties passed as filters
        unless query_filter[:party]
          dba_organizations = [current_user.party.dba_organization]
          dba_organizations = dba_organizations.concat(current_user.party.dba_organization.child_dba_organizations)
          product_types = product_types.scope_by_dba_organization(dba_organizations)
        end

        if sort and dir
          product_types = product_types.order("#{sort} #{dir}")
        end

        total_count = product_types.count

        if start and limit
          product_types = product_types.offset(start).limit(limit)
        end

        product_types = product_types.order('description')

        if context[:view]
          if context[:view] == 'mobile'
            render :json => {success: true,
                             total_count: total_count,
                             product_types: product_types.collect { |product_type| product_type.to_mobile_hash }}
          end
        else
          render :json => {success: true,
                           total_count: total_count,
                           product_types: product_types.collect { |product_type| product_type.to_data_hash }}
        end

      end

      def show
        product_type = ProductType.find(params[:id])

        render :json => {success: true,
                         product_type: product_type.to_data_hash}
      end

      def create
        begin
          ActiveRecord::Base.transaction do
            product_type = ProductType.new
            product_type.description = params[:description]
            product_type.sku = params[:sku]
            product_type.unit_of_measurement_id = params[:unit_of_measurement]
            product_type.comment = params[:comment]

            product_type.created_by_party = current_user.party

            product_type.save!

            #
            # For scoping by party, add party_id and role_type 'vendor' to product_party_roles table. However may want to override controller elsewhere
            # so that default is no scoping in erp_products engine
            #
            party_role = params[:party_role]
            party_id = params[:party_id]
            unless party_role.blank? or party_id.blank?
              product_type_party_role = ProductTypePtyRole.new
              product_type_party_role.product_type = product_type
              product_type_party_role.party_id = party_id
              product_type_party_role.role_type = RoleType.iid(party_role)
              product_type_party_role.save
            end
          end

          render :json => {success: true,
                           product_type: product_type.to_data_hash}

        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}

        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: 'Could not create product type'}
        end
      end

      def update
        begin
          ActiveRecord::Base.transaction do
            product_type = ProductType.find(params[:id])

            product_type.description = params[:description]
            product_type.sku = params[:sku]
            product_type.unit_of_measurement_id = params[:unit_of_measurement]
            product_type.comment = params[:comment]

            product_type.updated_by_party = current_user.party

            product_type.save!

            render :json => {success: true,
                             product_type: product_type.to_data_hash}
          end
        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}

        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: 'Could not update product type'}
        end
      end

      def destroy
        ProductType.find(params[:id]).destroy

        render :json => {:success => true}
      end

    end # ProductTypesController
  end # V1
end # API