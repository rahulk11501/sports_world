class Api::V2::AuthController < Api::V2::BaseController
  # Don't authenticate users just yet.
  skip_before_action :authenticate_api_user, except: :logout

  def logout
  
  end

  # DEPRECATED
  # now using http://assets.letsdogether.com/app_version.json
  def app_version

  end

  # Verify if provided username is valid or not.
  def verify_username

  end

  def sign_in

  end

  def password_sign_in

  end

  def sign_up
  end

  private

  def u_params

  end

  def user_params
    u_params.permit(:username, :email, :gender,
      :dob, :work, :education, :full_name)
  end

  def log_error(line, e)

  end

end
