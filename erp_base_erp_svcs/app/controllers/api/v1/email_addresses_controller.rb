module API
  module V1
    class EmailAddressesController < BaseController

=begin

 @api {get} /api/v1/email_addresses Index
 @apiVersion 1.0.0
 @apiName GetEmailAddresses
 @apiGroup Email Address

 @apiParam {String} [contact_purposes] Comma delimitted string of ContactPurpose internal identifiers to filter by

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Number} total_count Total count of records based on any filters applied
 @apiSuccess {Array} email_addresses List of EmailAddress records
 @apiSuccess {Number} email_addresses.id Id of EmailAddress

=end

      def index
        sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
        sort = sort_hash[:property] || 'description'
        dir = sort_hash[:direction] || 'ASC'

        contact_purposes = []
        if params[:contact_purposes].present?
          contact_purposes = ContactPurpose.where(internal_identifier: params[:contact_purposes].split(',')).all
        end

        email_addresses = EmailAddress

        if params[:party_id]
          email_addresses = email_addresses.for_party(Party.find(params[:party_id]), contact_purposes)
        else
          unless contact_purposes.empty?
            email_addresses = email_addresses.where(contact_purposes: {id: contact_purposes})
          end
        end

        if params[:query]
          email_addresses = email_addresses.where(EmailAddress.arel_table[:description].matches("%#{params[:query]}%"))
        end

        total_count = email_addresses.count

        if params[:limit].present?
          email_addresses = email_addresses.limit(params[:limit])
        end

        if params[:start].present?
          email_addresses = email_addresses.offset(params[:start])
        end

        email_addresses = email_addresses.uniq.order("#{sort} #{dir}")

        render :json => {success: true, total_count: total_count, email_addresses: email_addresses.all.collect(&:to_data_hash)}
      end

=begin

 @api {get} /api/v1/email_addresses/:id Index
 @apiVersion 1.0.0
 @apiName GetEmailAddresses
 @apiGroup Email Address

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Number} total_count Total count of records based on any filters applied
 @apiSuccess {Array} email_addresses List of EmailAddress records
 @apiSuccess {Number} email_addresses.id Id of EmailAddress

=end

      def show
        render json: {success: true, email_address: EmailAddress.find(params[:id]).to_data_hash}
      end

=begin

  @api {post} /api/v1/email_addresses Create
  @apiVersion 1.0.0
  @apiName CreateEmailAddress
  @apiGroup Email Address

  @apiParam {String} [contact_purposes] Comma delimitted string of ContactPurpose internal identifiers to filter by
  @apiParam {String} email_address Email Address
  @apiParam {String} description Description of Email Address

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} email_address EmailAddress record
  @apiSuccess {Number} email_address.id Id of EmailAddress

=end

      def create
        begin
          ActiveRecord::Base.transaction do
            email_address = EmailAddress.create(email_address: params[:email_address],
                                                description: params[:description])

            if params[:party_id].present?
              email_address.contact.contact_record = Party.find(params[:party_id])
              email_address.contact.save!
            end

            if params[:contact_purposes].present?
              params[:contact_purposes].split(',').each do |contact_purpose_iid|
                email_address.contact.contact_purposes << ContactPurpose.iid(contact_purpose_iid)
              end
            end

            if params[:is_primary].present?
              email_address.contact.is_primary = (params[:is_primary].to_bool === true)
            end

            email_address.created_by_party = current_user.party
            email_address.contact.save!
            email_address.save!

            render :json => {success: true, email_address: email_address.to_data_hash}
          end
        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: ex.message}
        end
      end

=begin

  @api {put} /api/v1/email_addresses/:id Update
  @apiVersion 1.0.0
  @apiName UpdateEmailAddress
  @apiGroup Email Address

  @apiParam {String} [contact_purposes] Comma delimitted string of ContactPurpose internal identifiers to filter by
  @apiParam {String} [email_address] Email Address
  @apiParam {String} [description] Description of Email Address

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} email_address EmailAddress record
  @apiSuccess {Number} email_address.id Id of EmailAddress

=end

      def update
        begin
          ActiveRecord::Base.transaction do
            email_address = EmailAddress.find(params[:id])

            if params[:description].present?
              email_address.description = params[:description]
            end

            if params[:email_address].present?
              email_address.email_address = params[:email_address]
            end

            if params[:contact_purposes].present?
              email_address.contact.contact_purposes.delete_all

              params[:contact_purposes].split(',').each do |contact_purpose_iid|
                email_address.contact.contact_purposes << ContactPurpose.iid(contact_purpose_iid)
              end
            end

            if params[:is_primary].present?
              email_address.contact.is_primary = (params[:is_primary].to_bool === true)
            end

            email_address.contact.save!
            email_address.save!

            email_address.updated_by_party = current_user.party
            email_address.save!

            render :json => {success: true, email_address: email_address.to_data_hash}
          end
        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # email error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: ex.message}
        end
      end

=begin

  @api {delete} /api/v1/email_addresses/:id Delete
  @apiVersion 1.0.0
  @apiName DeleteEmailAddress
  @apiGroup Email Address

  @apiSuccess {Boolean} success True if the request was successful

=end

      def destroy
        email_address = EmailAddress.find(params[:id])

        render json: {success: email_address.destroy}
      end

    end # EmailAddressesController
  end # V1
end # API
