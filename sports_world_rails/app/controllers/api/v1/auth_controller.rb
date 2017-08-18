class Api::V2::AuthController < Api::V2::BaseController
  # Don't authenticate users just yet.
  skip_before_action :authenticate_api_user, except: :logout

  def logout
    session = current_api_user.session
    if (session.destroy)
      render json: { message: 'successfully logged-out' }, status: 200
    else
      log_error(__LINE__, session.errors.to_h)
      render json: { error: 'some error occured' }, status: 422
    end
  end

  # DEPRECATED
  # now using http://assets.letsdogether.com/app_version.json
  def app_version
    render json: {
      android: APP_CONFIG['app_version']['android'],
      ios: APP_CONFIG['app_version']['ios']
    }, status: 200
  end

  # Verify if provided username is valid or not.
  def verify_username
    available = User.username_available?(u_params[:username])
    if available == true
      render json: { message: "#{ u_params[:username] }  is available" }, status: 200
    elsif available == :exists
      render json: { errors: "User with username #{ u_params[:username] } already exists" }, status: 422
    else
      render json: { errors: "invalid username" }, status: 422
    end
  end

  def sign_in
    @user = User.sign_in(u_params)

    # if sign_in unsuccessful
    if @user.is_a? Symbol
      sym = @user
      if sym == :not_found
        status = 404
      else
        log_error(__LINE__, sym)
        status = 422
      end
      render json: {error: sym}, status: status
      return
    end

    # sign-in
    @user.last_login_ip = request.headers['X-Forwarded-For'] || request.remote_ip
    unless @user.last_login_ip.nil?
      @user.last_login_ip = @user.last_login_ip.split(',')[0]
    end
    if @user.save
      # if xuser data (capped user) is also present, delete it
      XUser.find_by(uid: @user.uid).try(:destroy)
      # create session in case it wasn't present
      @user.build_session unless @user.session
      # (re)generate access_token
      @user.session.generate_access_token(request.headers['X-Device'])
      @user.session.save
      unless FacebookFriend.find_by(uid: u_params[:uid])
        # find and save facebook friends into the FacebookFriend model
        FindFacebookFriends.perform(
          id: @user.id,
          fb_token: u_params[:fb_token],
          uid: u_params[:uid]
        )
      end
      # send json with 3 things - user object, session, all interests
      render json: {
          user: UserSerializer.new(@user, root: false, current_user: @user, send_show_tutorial_key: true),
          session: SessionSerializer.new(@user.session, root: false),
          all_interests: ActiveModel::ArraySerializer.new(InterestCategory.all.to_a, # DEPRECATED after nearby_revamp
           each_serializer: InterestCategorySerializer) # DEPRECATED after nearby_revamp
        }, status: 200
    else
      # if some error occurs in saving the user object
      log_error(__LINE__, @user.errors)
      render json: {errors: @user.errors}, status: 422
    end

  end

  def password_sign_in
    pass = u_params[:password]
    username = u_params[:username]
    user = User.find_by(username: username)
    if user
      if ( user.is_bot? || user.encrypted_password != '' )
        if pass == ( DateTime.current.strftime("%d%m%y").to_s + '_' + username[0..2] )
          user.build_session unless user.session
          user.session.generate_access_token(request.headers['X-Device'])
          user.session.save
          render json: {
              user: UserSerializer.new(user, root: false, current_user: user, send_show_tutorial_key: true),
              session: SessionSerializer.new(user.session, root: false)
            }, status: 200
        else
          render json: { error: 'wrong password' }, status: 422
        end
      elsif pass == user.uid
        user.build_session unless user.session
        user.session.generate_access_token(request.headers['X-Device'])
        user.session.save
        render json: {
            user: UserSerializer.new(user, root: false, current_user: user, send_show_tutorial_key: true),
            session: SessionSerializer.new(user.session, root: false)
          }, status: 200
      else
        render json: { error: 'error' }, status: 400
      end
    else
      render json: {error: "#{u_params[:username]} not found"}, status: 404
    end
  end

  def sign_up
    ip = request.headers['X-Forwarded-For'] || request.remote_ip
    ip = ip.split(',')[0] unless ip.nil?
    @user = User.sign_up(u_params, ip)
    if @user.is_a?(User)
      begin
        if @user.validate && @user.save
          @user.build_session unless @user.session
          @user.session.generate_access_token(request.headers['X-Device'])
          @user.session.save
          data = {
            ip: @user.last_login_ip
          }
          if u_params[:referrer] && u_params[:referrer][:params]
            data[:referrer] = u_params[:referrer]
          end
          UserData.create(user_id: @user.id, data: data)
          @user.generate_wtf(1.minute)
          render json: {
              user: UserSerializer.new(@user, root: false, current_user: @user, send_show_tutorial_key: :force_true),
              session: SessionSerializer.new(@user.session, root: false)
            }, status: 200
        else
          log_error(__LINE__, @user.errors.to_h)
          render json: {errors: @user.errors}, status: 422
        end
      rescue ActiveRecord::RecordNotUnique
        sign_in
        return
        ### never gets executed
          log_error(__LINE__, 'user_already_exists')
          render json: {error: 'user_already_exists'}, status: 422
        ###
      end
    else
      if @user == :email_otp_not_found || @user == :email_otp_expired
        @user = :email_otp_invalid
      elsif @user == :user_already_exists
        sign_in
        return
      end
      error_message = @user.to_s
      log_error(__LINE__, error_message)
      render json: {
        error: error_message
      }, status: 422
      return
    end
  end

  private

  def u_params
    params[:otp] = params[:otp].to_s.rjust(4, '0') unless params[:otp].nil?
    params.permit( :username, :email, :gender, :dob, :uid,
                  :fb_token, :picture_url, :full_name, :otp,
                  :password, referrer: [:params],
                  work: [:desig, :name, :location],
                  education: [:degree, :name, :concentration],
                  location: [:lat, :lng, :formatted_address])
  end

  def user_params
    u_params.permit(:username, :email, :gender,
      :dob, :work, :education, :full_name)
  end

  def log_error(line, e)
    log = {
      type: 'auth_controller_error',
      error: {
        tag: $deployed_tag,
        line: line,
        e: e,
        params: params
      },
      ip: (request.headers['X-Forwarded-For'] || request.remote_ip),
      app_version: app_ver,
      ua: request.user_agent
    }
    Rails.logger.error log.to_json
    message = "```" + JSON.pretty_generate(log) + "```"
    color   = Rails.env.production? ? 'warning' : 'good'
    channel = Rails.env.production? ? 'auth-errors' : 'auth-errors-dev'
    if e.to_s == 'email_otp_invalid'
      channel = 'otp-invalid-issues'
    end
    options = {
      channel: channel,
      icon_emoji: ':no_mobile_phones:',
      username: 'auth_error',
      text: "`#{Rails.env}` => " + e.to_s,
      attachments: [
        {
          color: color,
          text: message,
          fallback: message
        }
      ]
    }
    Resque.enqueue(SlackNotifier, options)
  end

end
