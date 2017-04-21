module API
  module V1
    class BaseController < ActionController::Base

      class ApiError < StandardError; end

      before_filter :require_login
      layout false

      protected

      def not_authenticated
        render json: {success: false, message: 'Not Authenticated'}, status: 401
      end

    end
  end # V1
end # API
