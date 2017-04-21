module API
  module V1
    class ApplicationsController < BaseController

      def index
        # scope by dba_organization
        if params[:dba_organization_id].present?
          applications = Application.scope_by_dba(params[:dba_organization_id])
        elsif params[:user_id].present?
          applications = User.find(params[:user_id]).applications
        else
          applications = Application.scope_by_dba(current_user.party.dba_organization)
        end

        # scope by types if passed
        if params[:types].present?
          types = params[:types].split(',')

          # if types length is 1 then we only want tools or apps
          if types.length == 1
            if types.first == 'tool'
              applications = applications.tools
            elsif types.first == 'app'
              applications = applications.apps.order('sequence ASC')
            end
          end
        end

        respond_to do |format|
          format.tree do
            applications = applications.map do |application|
              hash = application.to_data_hash
              hash.delete(:id)
              hash[:leaf] = true

              hash
            end

            render :json => {success: true, applications: applications}
          end
          format.json do
            render :json => {
              success: true,
              applications: applications.each do |application|
                application.to_data_hash
              end
            }
          end
        end
      end

      def show
        application = Application.find(params[:id])

        render :json => {success: true, application: application.to_data_hash}
      end

      def create
        begin
          ActiveRecord::Base.transaction do
            name = params[:name].strip

            last_sequence = Application.scope_by_dba(current_user.party.dba_organization).apps.select('Max(sequence) as sequence').first.sequence
            if last_sequence.nil?
              sequence = 1
            else
              sequence = last_sequence + 1
            end

            application = Application.create(
              description: params[:name].strip,
              internal_identifier: (params[:internal_identifier].present? ? params[:internal_identifier].strip : Application.generate_unique_iid(name)),
              sequence: sequence
            )

            current_user.apps << application
            current_user.save

            # associate application to dba_org of current user
            application.add_party_with_role(current_user.party.dba_organization, RoleType.iid('dba_org'))

            render :json => {success: true, application: application.to_data_hash}
          end
        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}
        rescue StandardError => ex
          Rails.logger.error(ex.message)
          Rails.logger.error(ex.backtrace.join("\n"))

          # email notification
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: ex.message}
        end
      end

      def update
        begin
          ActiveRecord::Base.connection.transaction do

            application = Application.find(params[:id])

            application.description = params[:description].strip

            application.save!

            render json: {success: true, application: application.to_data_hash}

          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, message: invalid.record.errors.full_messages.join(', ')}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error updating Application'}
        end
      end

      def destroy
        application = Application.find(params[:id])
        success = false
        sequence = application.sequence

        begin
          ActiveRecord::Base.transaction do
            application.destroy

            #
            # Decrement sequence of all apps that came after deleted record
            #
            Application.scope_by_dba(current_user.party.dba_organization).apps.where('sequence > ?', sequence).readonly(false).each do |reorder_app|
              reorder_app.sequence = reorder_app.sequence - 1
              reorder_app.save
            end

            success = true
          end
        rescue => ex
          Rails.logger.error(ex.message)
          Rails.logger.error(ex.backtrace.join("\n"))

          # email notification
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier
        end

        render :json => {success: success}
      end

      def install
        begin
          ActiveRecord::Base.connection.transaction do
            if params[:user_id].present?
              user = User.find(params[:user_id])
            end

            # remove current applications
            application_ids = user.applications.pluck(:id)
            application_ids.each do |app_id|
              user.applications.delete(Application.find(app_id))
            end

            params[:application_iids].split(',').each do |application_iid|
              user.applications << Application.iid(application_iid)
            end

            render json: {success: true}
          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render json: {success: false, message: 'Error updating installed Applications'}
        end
      end

      def reorder
        apps = JSON.parse(params[:apps])

        apps.each do |application|
          app = Application.find(application['app_id'])
          app.sequence = application['sequence']
          app.save
        end

        render json: {success: true}
      end

    end # ApplicationsController
  end # V1
end # API
