module API
  module V1
    class CapabilitiesController < BaseController

      def index
        if params[:user_id].present?
          capabilities = User.find(params[:user_id]).capabilities
        else
          capabilities = Capability
        end

        respond_to do |format|
          format.json do
            query = params[:query]
            sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
            sort = sort_hash[:property] || 'description'
            dir = sort_hash[:direction] || 'ASC'
            limit = params[:limit]
            start = params[:start]

            if query
              capability_role_tbl = Capability.arel_table
              capabilities = capabilities.where(capability_role_tbl[:description].matches("%#{query}%"))

              total_count = capabilities.count
              capabilities = capabilities.order("#{sort} #{dir}")
            else
              total_count = capabilities.count
              capabilities = capabilities.order("#{sort} #{dir}")
            end

            if limit and start
              capabilities = capabilities.limit(limit).offset(start)
            end

            render json: {success: true, total_count: total_count, capabilities: capabilities.collect{|capability| capability.to_data_hash}}
          end
          format.tree do
            nodes = [].tap do |nodes|
              capabilities.all.each do |capability|
                nodes.push({
                             leaf: true,
                             internal_identifier: capability.id,
                             text: capability.description
                })
              end
            end

            render json: {success: true, capabilities: nodes}
          end
        end
      end

      def available
        type = params[:type]
        id = params[:id]

        sort = (params[:sort] || 'description').downcase
        sort = 'capabilities.description' if sort == 'description'
        dir = (params[:dir] || 'asc').downcase
        query_filter = params[:query_filter].strip rescue nil
        scope_type_ids = [ScopeType.find_by_internal_identifier('class').id, ScopeType.find_by_internal_identifier('query').id]

        statement = id.blank? ? Capability.joins(:capability_type) : type.constantize.find(id).capabilities_not.where("scope_type_id IN (#{scope_type_ids.join(',')})")
        statement = (params[:query_filter].blank? ? statement : statement.where("(UPPER(capabilities.description) LIKE UPPER('%#{query_filter}%'))"))
        available = statement.paginate(:page => page, :per_page => per_page, :order => "#{sort} #{dir}")

        render :json => {:total_count => statement.count, :capabilities => available.map { |capability| capability.to_data_hash }}
      end

      def selected
        type = params[:type]
        id = params[:id]

        sort = (params[:sort] || 'description').downcase
        sort = 'capabilities.description' if sort == 'description'
        dir = (params[:dir] || 'asc').downcase
        query_filter = params[:query_filter].strip rescue nil
        scope_type_ids = [ScopeType.find_by_internal_identifier('class').id, ScopeType.find_by_internal_identifier('query').id]

        statement = id.blank? ? Capability.joins(:capability_type) : type.constantize.find(id).capabilities.where("scope_type_id IN (#{scope_type_ids.join(',')})")
        statement = (params[:query_filter].blank? ? statement : statement.where("(UPPER(capabilities.description) LIKE UPPER('%#{query_filter}%'))"))
        selected = statement.paginate(:page => page, :per_page => per_page, :order => "#{sort} #{dir}")

        render :json => {:total_count => statement.count, :capabilities => selected.map { |capability| capability.to_data_hash }}
      end

      def add
        begin
          type = params[:type]
          id = params[:id]
          capability_ids = JSON.parse(params[:capability_ids])

          assign_to = type.constantize.find(id)
          capability_ids.each do |capability_id|
            capability = Capability.find(capability_id)
            case type
            when 'User'
              assign_to.add_capability(capability)
            when 'SecurityRole'
              assign_to.add_capability(capability)
            when 'Group'
              assign_to.add_capability(capability)
            end
          end

          render :json => {:success => true, :message => 'Capability(s) Added'}
        rescue Exception => e
          Rails.logger.error e.message
          Rails.logger.error e.backtrace.join("\n")
          render :inline => {
            :success => false,
            :message => e.message
          }.to_json
        end
      end

      def remove
        begin
          type = params[:type]
          id = params[:id]
          capability_ids = JSON.parse(params[:capability_ids])

          assign_to = type.constantize.find(id)
          capability_ids.each do |capability_id|
            capability = Capability.find(capability_id)
            case type
            when 'User'
              assign_to.remove_capability(capability)
            when 'SecurityRole'
              assign_to.remove_capability(capability)
            when 'Group'
              assign_to.remove_capability(capability)
            end
          end

          render :json => {:success => true, :message => 'Capability(s) Removed'}
        rescue Exception => e
          Rails.logger.error e.message
          Rails.logger.error e.backtrace.join("\n")
          render :inline => {
            :success => false,
            :message => e.message
          }.to_json
        end
      end


      def page
        offset = params[:start].to_f
        offset > 0 ? (offset / params[:limit].to_f).to_i + 1 : 1
      end

      def per_page
        params[:limit].nil? ? 10 : params[:limit].to_i
      end

    end # CapabilitiesController
  end # V1
end # API
