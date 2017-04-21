module API
  module V1
    class SecurityRolesController < BaseController

      def index
        query = params[:query]
        parent_iids = params[:parent]
        include_admin = params[:include_admin]

        security_roles = []

        if parent_iids
          parent = nil

          # if the parent param is a comma separated string then
          # there are multiple parents
          parent_iids.split(',').each do |parent_iid|
            parent = nil

            # if the parent param is a colon separated string then
            # the parent is nested from left to right
            parent_iid.split(':').each do |nested_parent_iid|
              if parent
                parent = parent.children.where('internal_identifier = ?', nested_parent_iid).first
              else
                parent = SecurityRole.where('internal_identifier = ?', nested_parent_iid).first
              end
            end

            security_roles = security_roles.concat parent.children
          end

          security_roles = SecurityRole.where(id: security_roles.collect(&:id))
        elsif params[:user_id].present?
          security_roles = User.find(params[:user_id]).party.security_roles
        else
          security_roles = nil
        end

        respond_to do |format|
          format.tree do
            nodes = [].tap do |nodes|
              unless security_roles
                security_roles = SecurityRole.roots
              end

              security_roles.all.each do |security_role|
                nodes.push(security_role.to_tree_hash)
              end
            end

            if include_admin
              nodes.unshift SecurityRole.iid('admin').to_tree_hash
            end

            render :json => {success: true, security_roles: nodes}
          end
          format.json do
            sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
            sort = sort_hash[:property] || 'description'
            dir = sort_hash[:direction] || 'ASC'
            limit = params[:limit]
            start = params[:start]

            unless security_roles
              security_roles = SecurityRole
            end

            if query
              security_role_tbl = SecurityRole.arel_table
              statement = security_roles.where(security_role_tbl[:description].matches("%#{query}%")
                                               .or(security_role_tbl[:internal_identifier].matches("%#{query}%")))

              total_count = statement.count
              security_roles = statement.order("#{sort} #{dir}")
            else
              total_count = security_roles.count
              security_roles = security_roles.order("#{sort} #{dir}")
            end

            if limit and start
              security_roles = security_roles.limit(limit).offset(start)
            end

            if include_admin
              security_roles = security_roles.all
              security_roles.unshift SecurityRole.iid('admin')
            end

            render :json => {
              success: true, total_count: total_count,
              security_roles: security_roles.collect do |security_role|
                security_role.to_data_hash
              end
            }
          end
        end
      end

      def available
        type = params[:type]
        id = params[:id]

        sort = (params[:sort] || 'description').downcase
        dir = (params[:dir] || 'asc').downcase
        query_filter = params[:query_filter].strip rescue nil

        statement = id.blank? ? SecurityRole : type.constantize.find(id).roles_not
        statement = (params[:query_filter].blank? ? statement : statement.where("UPPER(security_roles.description) LIKE UPPER('%#{query_filter}%')"))
        available = statement.paginate(:page => page, :per_page => per_page, :order => "#{sort} #{dir}")

        render :json => {:total_count => statement.count, :security_roles => available.map { |security_role| security_role.to_data_hash }}
      end

      def selected
        type = params[:type]
        id = params[:id]

        sort = (params[:sort] || 'description').downcase
        dir = (params[:dir] || 'asc').downcase
        query_filter = params[:query_filter].strip rescue nil

        statement = id.blank? ? SecurityRole : type.constantize.find(id).roles
        statement = (params[:query_filter].blank? ? statement : statement.where("UPPER(security_roles.description) LIKE UPPER('%#{query_filter}%')"))
        selected = statement.paginate(:page => page, :per_page => per_page, :order => "#{sort} #{dir}")

        render :json => {:total_count => statement.count, :security_roles => selected.map { |security_role| security_role.to_data_hash }}
      end

      def add
        begin
          type = params[:type]
          id = params[:id]
          security_role_ids = JSON.parse(params[:security_role_ids])

          assign_to = type.constantize.find(id)
          security_role_ids.each do |role_id|
            role = SecurityRole.find(role_id)
            case type
            when 'User'
              assign_to.add_role(role)
            when 'Group'
              assign_to.add_role(role)
            when 'Capability'
              role.add_capability(assign_to)
            end
          end

          render :json => {:success => true, :message => 'Security Roles(s) Added'}
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {:success => false, :message => ex.message}
        end
      end

      def remove
        begin
          type = params[:type]
          id = params[:id]
          security_role_ids = JSON.parse(params[:security_role_ids])

          assign_to = type.constantize.find(id)
          security_role_ids.each do |role_id|
            role = SecurityRole.find(role_id)
            case type
            when 'User'
              assign_to.remove_role(role)
            when 'Group'
              assign_to.remove_role(role)
            when 'Capability'
              role.remove_capability(assign_to)
            end
          end

          render :json => {:success => true, :message => 'Security Roles(s) Removed'}
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {:success => false, :message => ex.message}
        end
      end

      def create
        begin
          ActiveRecord::Base.connection.transaction do
            security_role = SecurityRole.create!(description: params[:description].strip,
                                                internal_identifier: params[:internal_identifier].strip)


            if params[:parent]
              security_role.move_to_child_of(SecurityRole.iid(params[:parent]))
            end

            render :json => {
                     success: true,
                     security_role: security_role.to_data_hash,
                     message: 'Role created successfully'
                   }
          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          message = "<ul>"
          invalid.record.errors.collect do |e, m|
            message << "<li>#{e} #{m}</li>"
          end
          message << "</ul>"

          render :json => {:success => false, :message => message}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")
          
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {:success => false, :message => 'Error creating Security Role'}
        end
      end

      def update
        begin
          ActiveRecord::Base.connection.transaction do
            security_role = SecurityRole.find(params[:id])
            security_role.description = params[:description].strip
            security_role.internal_identifier = params[:internal_identifier].strip

            security_role.save!

            render json: {success: true, security_role: security_role.to_data_hash}
          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          message = "<ul>"
          invalid.record.errors.collect do |e, m|
            message << "<li>#{e} #{m}</li>"
          end
          message << "</ul>"

          render :json => {:success => false, :message => message}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {:success => false, :message => 'Error updating Security Role'}
        end
      end

      def destroy
        security_role = SecurityRole.find(params[:id])

        render json: {success: security_role.destroy}
      end


      def page
        offset = params[:start].to_f
        offset > 0 ? (offset / params[:limit].to_f).to_i + 1 : 1
      end

      def per_page
        params[:limit].nil? ? 10 : params[:limit].to_i
      end

    end # SecurityRolesController
  end # V1
end # API
