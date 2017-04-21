module API
  module V1
    class ContactPurposesController < BaseController

      def index
        contact_purposes = if params[:ids].present?
                             [ContactPurpose.where(id: params[:ids])]
                           else
                             ContactPurpose.all
                           end

        render json: {success: true,
                      contact_purposes: contact_purposes.collect(&:to_data_hash)}
      end

      def show
        contact_purpose = ContactPurpose.find(params[:id])

        render json: {success: true, contact_purpose: contact_purpose.to_data_hash}
      end

    end # ContactPurposesController
  end # V1
end # API