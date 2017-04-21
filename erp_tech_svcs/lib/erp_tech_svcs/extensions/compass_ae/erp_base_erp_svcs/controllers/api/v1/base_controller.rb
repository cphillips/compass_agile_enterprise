API::V1::BaseController.class_eval do

  # check_username is added because the users api controller is loaded before this file is loaded
  before_filter :require_login, except: [:generate_auth_token, :auth_token_valid, :check_username]

  def generate_auth_token
    if params[:username] && params[:password] && (user = login(params[:username].strip, params[:password].strip))
      auth_token = user.generate_auth_token!

      # log when someone logs in
      ErpTechSvcs::ErpTechSvcsAuditLog.successful_login(user)

      render :json => {success: true, user_id: user.id, auth_token: auth_token.token, auth_token_expires_at: auth_token.expires_at}
    else
      render :json => {success: false}
    end
  end

  def auth_token_valid
    if params[:current_user_id] && params[:auth_token]
      user = User.find(params[:current_user_id])

      auth_token = user.auth_tokens.where(token: params[:auth_token]).first

      if auth_token
        render json: {success: true}
      else
        render json: {success: false}
      end
    else
      render :json => {success: false, message: 'current_user_id and auth_token are required'}
    end
  end

  def revoke_auth_token
    auth_token = current_user.auth_tokens.where(token: params[:auth_token]).first

    if auth_token
      render json: {success: auth_token.destroy}
    else
      render json: {success: false}
    end

  end

end # API
