module API
  module V1
    class PostalAddressesController < BaseController

=begin

 @api {get} /api/v1/postal_addresses Index
 @apiVersion 1.0.0
 @apiName GetPostalAddresses
 @apiGroup Postal Address

 @apiParam {String} [contact_purposes] Comma delimited string of ContactPurpose internal identifiers to filter by
 @apiParam {String} [query] Query to search description by

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Number} total_count Total count of records based on any filters applied
 @apiSuccess {Array} postal_addresses List of PostalAddress records
 @apiSuccess {Number} postal_addresses.id Id of PostalAddress

=end

      def index
        sort_hash = params[:sort].blank? ? {} : Hash.symbolize_keys(JSON.parse(params[:sort]).first)
        sort = sort_hash[:property] || 'description'
        dir = sort_hash[:direction] || 'ASC'

        contact_purposes = []
        if params[:contact_purposes].present?
          contact_purposes = ContactPurpose.where(internal_identifier: params[:contact_purposes].split(',')).all
        end

        postal_addresses = PostalAddress

        if params[:party_id]
          postal_addresses = postal_addresses.for_party(Party.find(params[:party_id]), contact_purposes)
        else
          unless contact_purposes.empty?
            postal_addresses = postal_addresses.where(contact_purposes: {id: contact_purposes})
          end
        end

        if params[:query]
          postal_addresses = postal_addresses.where(PostalAddress.arel_table[:description].matches("%#{params[:query]}%"))
        end

        total_count = postal_addresses.count

        if params[:limit].present?
          postal_addresses = postal_addresses.limit(params[:limit])
        end

        if params[:start].present?
          postal_addresses = postal_addresses.offset(params[:start])
        end

        postal_addresses = postal_addresses.uniq.order("#{sort} #{dir}")

        render :json => {success: true, total_count: total_count, postal_addresses: postal_addresses.all.collect(&:to_data_hash)}
      end

=begin

 @api {get} /api/v1/postal_addresses/:id Index
 @apiVersion 1.0.0
 @apiName GetPostalAddresses
 @apiGroup Postal Address

 @apiSuccess {Boolean} success True if the request was successful
 @apiSuccess {Number} total_count Total count of records based on any filters applied
 @apiSuccess {Array} postal_addresses List of PostalAddress records
 @apiSuccess {Number} postal_addresses.id Id of PostalAddress

=end

      def show
        render json: {success: true, postal_address: PostalAddress.find(params[:id]).to_data_hash}
      end

=begin

  @api {post} /api/v1/postal_addresses Create
  @apiVersion 1.0.0
  @apiName CreatePostalAddress
  @apiGroup Postal Address
  
  @apiParam {String} description Description of Postal Address
  @apiParam {String} [contact_purposes] Comma delimitted string of ContactPurpose internal identifiers to filter by
  @apiParam {String} address_line_1 Address Line 1
  @apiParam {String} [address_line_1] Address Line 2
  @apiParam {String} city City
  @apiParam {String} state State
  @apiParam {String} zip Zip
  @apiParam {String} country Country

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} postal_address PostalAddress record
  @apiSuccess {Number} postal_address.id Id of PostalAddress

=end

      def create
        begin
          ActiveRecord::Base.transaction do
            postal_address = PostalAddress.create(address_line_1: params[:address_line_1],
                                                  address_line_2: params[:address_line_2],
                                                  city: params[:city],
                                                  state: params[:state],
                                                  zip: params[:zip],
                                                  country: params[:country],
                                                  description: params[:description])

            if params[:party_id].present?
              postal_address.contact.contact_record = Party.find(params[:party_id])
              postal_address.contact.save!
            end

            if params[:contact_purposes].present?
              params[:contact_purposes].split(',').each do |contact_purpose_iid|
                postal_address.contact.contact_purposes << ContactPurpose.iid(contact_purpose_iid)
              end
            end

            if params[:is_primary].present?
              postal_address.contact.is_primary = (params[:is_primary].to_bool === true)
            end

            postal_address.created_by_party = current_user.party
            postal_address.contact.save!
            postal_address.save!

            render :json => {success: true, postal_address: postal_address.to_data_hash}
          end
        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # postal error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: ex.message}
        end
      end

=begin

  @api {put} /api/v1/postal_addresses/:id Update
  @apiVersion 1.0.0
  @apiName UpdatePostalAddress
  @apiGroup Postal Address

  @apiParam {String} [contact_purposes] Comma delimitted string of ContactPurpose internal identifiers to filter by
  @apiParam {String} [address_line_1] Address line 1
  @apiParam {String} [address_line_2] Address line 2
  @apiParam {String} [city] City
  @apiParam {String} [state] State
  @apiParam {String} [zip] Zip
  @apiParam {String} [country] Country
  @apiParam {String} [description] Description of Postal Address

  @apiSuccess {Boolean} success True if the request was successful
  @apiSuccess {Object} postal_address PostalAddress record
  @apiSuccess {Number} postal_address.id Id of PostalAddress

=end

      def update
        begin
          ActiveRecord::Base.transaction do
            postal_address = PostalAddress.find(params[:id])

            if params[:description].present?
              postal_address.description = params[:description]
            end

            if params[:address_line_1].present?
              postal_address.address_line_1 = params[:address_line_1]
            end

            if params[:address_line_2].present?
              postal_address.address_line_2 = params[:address_line_2]
            end

            if params[:city].present?
              postal_address.city = params[:city]
            end

            if params[:state].present?
              postal_address.state = params[:state]
            end

            if params[:zip].present?
              postal_address.zip = params[:zip]
            end

            if params[:country].present?
              postal_address.country = params[:country]
            end

            if params[:contact_purposes].present?
              postal_address.contact.contact_purposes.delete_all

              params[:contact_purposes].split(',').each do |contact_purpose_iid|
                postal_address.contact.contact_purposes << ContactPurpose.iid(contact_purpose_iid)
              end
            end

            if params[:is_primary].present?
              postal_address.contact.is_primary = (params[:is_primary].to_bool === true)
            end

            postal_address.contact.save!
            postal_address.save!

            postal_address.updated_by_party = current_user.party
            postal_address.save!

            render :json => {success: true, postal_address: postal_address.to_data_hash}
          end
        rescue ActiveRecord::RecordInvalid => invalid

          render :json => {success: false, message: invalid.record.errors.full_messages.join(', ')}
        rescue => ex
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace.join("\n")

          # postal error
          ExceptionNotifier.notify_exception(ex) if defined? ExceptionNotifier

          render :json => {success: false, message: ex.message}
        end
      end

=begin

  @api {delete} /api/v1/postal_addresses/:id Delete
  @apiVersion 1.0.0
  @apiName DeletePostalAddress
  @apiGroup Postal Address

  @apiSuccess {Boolean} success True if the request was successful

=end

      def destroy
        postal_address = PostalAddress.find(params[:id])

        render json: {success: postal_address.destroy}
      end

    end # PostalAddressesController
  end # V1
end # API
