module API
  module V1
    class GroupsController < BaseController

      def index
        if params[:user_id].present?
          groups = User.find(params[:user_id]).groups
        else
          groups = Group
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
              group_role_tbl = Group.arel_table
              groups = groups.where(group_role_tbl[:description].matches("%#{query}%"))

              total_count = groups.count
              groups = groups.order("#{sort} #{dir}")
            else
              total_count = groups.count
              groups = groups.order("#{sort} #{dir}")
            end

            if limit and start
              groups = groups.limit(limit).offset(start)
            end

            render json: {success: true, total_count: total_count, groups: groups.collect{|group| group.to_data_hash}}
          end
          format.tree do
            nodes = [].tap do |nodes|
              groups.all.each do |group|
                nodes.push({
                             leaf: true,
                             internal_identifier: group.id,
                             text: group.description
                })
              end
            end

            render json: {success: true, groups: nodes}
          end
        end
      end

      def available
        type = params[:type]
        id = params[:id]

        sort = (params[:sort] || 'description').downcase
        sort = 'groups.description' if sort == 'description'
        dir = (params[:dir] || 'asc').downcase
        query_filter = params[:query_filter].strip rescue nil

        statement = id.blank? ? Group : type.constantize.find(id).groups_not

        statement = (params[:query_filter].blank? ? statement : statement.where("UPPER(groups.description) LIKE UPPER('%#{query_filter}%')"))
        available = statement.paginate(:page => page, :per_page => per_page, :order => "#{sort} #{dir}")

        render :json => {:total_count => statement.count, :groups => available.map { |group| group.to_data_hash }}
      end

      def selected
        type = params[:type]
        id = params[:id]

        sort = (params[:sort] || 'description').downcase
        sort = 'groups.description' if sort == 'description'
        dir = (params[:dir] || 'asc').downcase
        query_filter = params[:query_filter].strip rescue nil

        statement = id.blank? ? Group : type.constantize.find(id).groups
        statement = (params[:query_filter].blank? ? statement : ar.where("UPPER(groups.description) LIKE UPPER('%#{query_filter}%')"))
        selected = statement.paginate(:page => page, :per_page => per_page, :order => "#{sort} #{dir}")

        render :json => {:total_count => statement.count, :groups => selected.map { |group| group.to_data_hash }}
      end

      def add
        begin
          type = params[:type]
          id = params[:id]
          selected = JSON.parse(params[:group_ids])

          assign_to = type.constantize.find(id)
          selected.each do |group_id|
            group = Group.find(group_id)
            case type
            when 'User'
              group.add_user(assign_to)
            when 'SecurityRole'
              group.add_role(assign_to)
            when 'Capability'
              group.add_capability(assign_to)
            end
          end

          render :json => {:success => true, :message => 'Group(s) Added'}
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
          selected = JSON.parse(params[:group_ids])

          assign_to = type.constantize.find(id)
          selected.each do |group_id|
            group = Group.find(group_id)
            case type
            when 'User'
              group.remove_user(assign_to)
            when 'SecurityRole'
              group.remove_role(assign_to)
            when 'Capability'
              group.remove_capability(assign_to)
            end
          end

          render :json => {:success => true, :message => 'Group(s) Removed'}
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
            group = Group.create(description: params[:description].strip)

            render json: {success: true, security_role: group.to_data_hash}
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

          render :json => {:success => false, :message => 'Error creating Group'}
        end
      end

      def update
        begin
          ActiveRecord::Base.connection.transaction do
            group = Group.find(params[:id])

            group.description = params[:description].strip
            group.save!

            render json: {success: true, group: group.to_data_hash}
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

          render :json => {:success => false, :message => 'Error update Group'}
        end
      end

      def destroy
        group = Group.find(params[:id])

        render json: {success: group.destroy}
      end

      def effective_security
        begin
          render :json => {:success => true, :capabilities => Group.find(params[:id]).class_capabilities_to_hash}
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :inline => {:success => false, :message => ex.message}
        end
      end

      protected

      def page
        offset = params[:start].to_f
        offset > 0 ? (offset / params[:limit].to_f).to_i + 1 : 1
      end

      def per_page
        params[:limit].nil? ? 10 : params[:limit].to_i
      end

    end # GroupsController
  end # V1
end # API
