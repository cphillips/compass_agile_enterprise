API::V1::PartiesController.class_eval do

  def user
    party = Party.find(params[:id])

    user = party.user

    if user
      render json: {success: true, user: user.to_data_hash}
    else
      render json: {success: true, user: nil}
    end
  end

end
