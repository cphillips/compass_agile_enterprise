module API
  module V1
    class UsersController < BaseController

      def index
        sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
        sort = sort_hash[:property] || 'username'
        dir = sort_hash[:direction] || 'ASC'
        limit = params[:limit] || 25
        start = params[:start] || 0

        # scope users by dba_organization and any of its children dba_orgs
        dba_organization = current_user.party.dba_organization
        dba_org_ids = dba_organization.child_dba_organizations.collect(&:id)
        dba_org_ids.push(dba_organization.id)
        dba_org_ids.uniq!

        users = User.joins(:party).joins("inner join party_relationships as dba_reln on
                          (dba_reln.party_id_from = parties.id
                          and
                          dba_reln.party_id_to in (#{dba_org_ids.join(',')})
                          and
                          dba_reln.role_type_id_to = #{RoleType.iid('dba_org').id}
                          )")

        query_filter = params[:query_filter].blank? ? {} : JSON.parse(params[:query_filter]).symbolize_keys

        users = User.apply_filters(query_filter, users)

        if params[:username]
          users = users.where('username like ? or email like ?', "%#{params[:username]}%", "%#{params[:username]}%")
        end

        total_count = users.uniq.count
        users = users.order("#{sort} #{dir}").offset(start).limit(limit)

        render json: {total_count: total_count, users: users.uniq.collect(&:to_data_hash)}
      end

      def show
        user = User.find(params[:id])

        render json: {success: true, user: user.to_data_hash}
      end

      def check_username
        if User.where('username = ?', params[:username]).first
          render json: {success: false}
        else
          render json: {success: true}
        end
      end

      def create
        begin
          ActiveRecord::Base.connection.transaction do
            current_user.with_capability(:create, 'User') do

              user = create_user

              render :json => {:success => true, user: user.to_data_hash}
            end
          end
        rescue ErpTechSvcs::Utils::CompassAccessNegotiator::Errors::UserDoesNotHaveCapability => ex
          render :json => {:success => false, :message => ex.message, :user => nil}
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          message = "<ul>"
          invalid.record.errors.collect do |e, m|
            message << "<li>#{e} #{m}</li>"
          end
          message << "</ul>"

          render :json => {:success => false, :message => message, :user => nil}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {:success => false, :message => 'Error creating user', :user => nil}
        end
      end

      def update
        begin
          ActiveRecord::Base.transaction do

            user = update_user

            render :json => {:success => true, :message => 'User updated', :user => user.to_data_hash}
          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors.full_messages, :user => nil}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {:success => false, :message => 'Error updating user', :user => nil}
        end
      end

      def reset_password
        begin
          user = User.find(params[:id])

          user.add_instance_attribute(:reset_password_url, (params[:reset_password_url] || '/erp_app/reset_password'))
          user.add_instance_attribute(:domain, params[:domain])
          user.deliver_reset_password_instructions!
          message = "Password has been reset. An email has been sent with further instructions to #{user.email}."
          success = true
          render :json => {:success => success, :message => message}
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {:success => false, :message => 'Could not reset password'}
        end
      end

      def destroy
        user = User.find(params[:id])

        # get the party as it will also destroy the user
        party = user.party
        party.destroy

        render :json => {:success => true}
      end

      def effective_security
        user = User.find(params[:id])

        render :json => {:success => true, :capabilities => user.class_capabilities_to_hash}
      end

      def update_security
        begin
          ActiveRecord::Base.transaction do
            user = User.find(params[:id])

            user.remove_all_security_roles
            user.add_security_roles(params[:security_role_iids].split(','))

            user.remove_all_groups
            user.add_groups(params[:group_ids].split(',').map{|group_id| Group.find(group_id)})

            user.remove_all_capabilities
            user.add_capabilities(params[:capability_ids].split(',').map{|capability_id| Capability.find(capability_id)})

            render json: {success: true}
          end
        rescue ActiveRecord::RecordInvalid => invalid
          Rails.logger.error invalid.record.errors

          render :json => {:success => false, :message => invalid.record.errors.full_messages, :user => nil}
        rescue StandardError => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {:success => false, :message => 'Error updating security', :user => nil}
        end
      end

      def update_profile_image
        result = {:success => true}

        begin
          ActiveRecord::Base.transaction do
            User.find(params[:id]).set_profile_image(params[:file].read, params[:file].original_filename)
          end
        rescue => ex
          logger.error ex.message
          logger.error ex.backtrace.join("\n")

          result = {:success => false, :error => "Error uploading profile image"}
        end

        render :json => result
      end

      protected

      # Create User
      #
      # @return [User] Newly created user
      def create_user
        user = User.new(
          :email => params[:email],
          :username => params[:username],
          :password => params[:password],
          :password_confirmation => params[:password_confirmation]
        )

        # set this to tell activation where to redirect_to for login and temp password
        login_url = params[:login_url].blank? ? '/erp_app/login' : params[:login_url]

        # if a website was selected then set it so we can use the any templates in that website
        unless params['website_id'].blank?
          user.add_instance_attribute(:website_id, params['website_id'])
        end

        #set this to tell activation where to redirect_to for login and temp password
        user.add_instance_attribute(:login_url, login_url)
        user.add_instance_attribute(:temp_password, params[:password])

        if params[:auto_activate] == 'yes'
          user.skip_activation_email = true
        end

        if params[:time_zone].present?
          user.time_zone = params[:time_zone]
        end

        user.save!

        if params[:auto_activate] == 'yes'
          user.activate!
        end

        if params[:party_id]
          user.party = Party.find(params[:party_id])
          user.save!
        else
          individual = Individual.create(:gender => params[:gender],
                                         :current_first_name => params[:first_name],
                                         :current_last_name => params[:last_name])
          user.party = individual.party
          user.save

          user.party.created_by_party = current_user.party
          user.party.save!

          # add employee role to party
          party = individual.party
          party.add_role_type(RoleType.find_or_create('employee', 'Employee'))

          # associate the new party to the dba_organization of the user creating this user
          relationship_type = RelationshipType.find_or_create(RoleType.find_or_create('dba_org', 'Doing Business As Organization'),
                                                              RoleType.find_or_create('employee', 'Employee'))
          party.create_relationship(relationship_type.description,
                                    current_user.party.dba_organization.id,
                                    relationship_type)
        end

        if params[:profile_image]
          user.set_profile_image(params[:profile_image].read, params[:profile_image].original_filename)
        end

        user
      end

      # Update User
      #
      # @return [User] Updated user
      def update_user
        if params[:id]
          user = User.find(params[:id])
          party = user.party
        else
          user = current_user
          party = user.party
        end

        if params[:password].present?
          user.password = params[:password].strip
          if params[:password_confirmation].present?
            user.password_confirmation = params[:password_confirmation].strip
          else
            user.password_confirmation = params[:password].strip
          end
        end

        if params[:username].present?
          user.username = params[:username].strip
        end

        if params[:status]
          user.activation_state = params[:status]
        end

        if params[:email].present?
          user.email = params[:email].strip
        end

        if params[:time_zone].present?
          user.time_zone = params[:time_zone]
        end

        user.save!

        business_party = party.business_party

        # update business party information
        if params[:first_name].present?
          business_party.current_first_name = params[:first_name].strip
        end

        if params[:last_name].present?
          business_party.current_last_name = params[:last_name].strip
        end

        if params[:profile_image]
          user.set_profile_image(params[:profile_image].read, params[:profile_image].original_filename)
        end

        user.party.updated_by_party = current_user.party
        user.party.save!

        user
      end

    end # UsersController
  end # V1
end # API
