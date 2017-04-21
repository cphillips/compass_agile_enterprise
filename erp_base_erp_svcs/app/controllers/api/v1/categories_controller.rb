module API
  module V1
    class CategoriesController < BaseController

      def index
        sort = 'description'
        dir = 'ASC'
        limit = nil
        start = nil

        unless params[:sort].blank?
          sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
          sort = sort_hash[:property] || 'description'
          dir = sort_hash[:direction] || 'ASC'
        end

        limit = params[:limit] || 25
        start = params[:start] || 0

        query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys

        if params[:parent_id]
          query_filter[:parent_id] = params[:parent_id]
        end

        # hook method to apply any scopes passed via parameters to this api
        categories = Category.apply_filters(query_filter)

        # scope by dba_organizations if there are no parties passed as filters
        dba_organizations = [current_user.party.dba_organization]
        dba_organizations = dba_organizations.concat(current_user.party.dba_organization.child_dba_organizations)
        categories = categories.by_tenant(dba_organizations)

        if query_filter[:with_products]
          categories = categories.where(categories: {id: Category.with_products(dba_organizations)})
        end

        respond_to do |format|
          format.json do

            if sort and dir
              categories = categories.except(:order).order("#{sort} #{dir}")
            end

            total_count = categories.count

            if start and limit
              categories = categories.offset(start).limit(limit)
            end

            render :json => {success: true,
                             total_count: total_count,
                             categories: categories.collect { |item| item.to_data_hash }}
          end
          format.tree do

            if params[:parent_id]
              render :json => {success: true,
                               categories: Category.find(params[:parent_id]).children_to_tree_hash({child_ids: categories})}
            else
              nodes = [].tap do |nodes|
                categories.roots.except(:order).order("#{sort} #{dir}").each do |root|
                  nodes.push(root.to_tree_hash)
                end
              end

              render :json => {success: true,
                               categories: nodes}
            end

          end
          format.all_representation do

            total_count = categories.count

            if start and limit
              categories = categories.offset(start).limit(limit)
            end

            if params[:parent_id].present?
              render :json => {success: true,
                               total_count: total_count,
                               categories: Category.to_all_representation(Category.find(params[:parent_id]))}, content_type: 'application/json'
            else


              render :json => {success: true,
                               total_count: total_count,
                               categories: Category.to_all_representation(nil, [], 0, categories.roots)}, content_type: 'application/json'
            end
          end
        end
      end

      def show
        category = Category.find(params[:id])

        render json: {category: category.to_data_hash}
      end

      def create
        parent_id = params[:parent_id]

        begin
          ActiveRecord::Base.transaction do
            category = Category.new(
              description: params[:description].strip

            )

            if params[:internal_identifier].present?
              category.internal_identifier = params[:internal_identifier].strip
            else
              category.internal_identifier = Category.generate_unique_iid(params[:description].strip)
            end

            category.save!

            if parent_id and parent_id != 'No Parent'
              parent = Category.find(parent_id)
              if parent
                category.move_to_child_of(parent)
              end
            end

            category.set_tenant!(current_user.party.dba_organization)

            render json: {success: true, category: category.to_data_hash}
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

      def update
        category = Category.find(params[:id])

        begin
          ActiveRecord::Base.transaction do
            if params[:description].present?
              category.description = params[:description].strip
            end

            if params[:internal_identifier].present?
              category.internal_identifier = params[:internal_identifier].strip
            end

            category.save!

            render json: {success: true, category: category.to_data_hash}
          end
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Application Error'}
        end
      end

      def destroy
        category = Category.find(params[:id])

        category.destroy

        render json: {success: true}
      end

    end # CategoriesController
  end # V1
end # API
