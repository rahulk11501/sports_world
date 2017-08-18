module  UserAuth
  extend ActiveSupport::Concern
  class_methods do


    def auth_info_valid?(options)
      byebug
      if options[:oauth_provider] == 'fb'
        fb_info_valid?(options)
      elsif options[:oauth_provider] == 'google'
        google_info_valid?(options)
      end
    end

    def fb_info_valid?(options)
      byebug
      fb_token = options[:auth_token]
      if options[:email]
        field = 'email'
        field_val = options[:email]
      elsif options[:uid]
        field = 'id'
        field_val = options[:uid]
      end
      response=JSON.parse(
        HTTParty.get(
          APP_CONFIG['fb']['graph_api_base'] + "/me?fields=#{field}&access_token=#{fb_token}",
          format: 'json'
        )
      )
      if response[field]
        return response[field] == field_val
      else
        return false
      end
    end

    def google_info_valid?(options)
      byebug
      id_token = options[:auth_token]
      response=JSON.parse(
        HTTParty.get(
          APP_CONFIG['google']['oauth']['base'] + "?id_token=" + "#{id_token}",
          format: 'json'
        )
      )
      # https://www.googleapis.com/oauth2/v3/tokeninfo?id_token=XYZ123
      return response['aud'] == APP_CONFIG['google']['oauth']['client_id']
    end

    def sign_up(options, ip = nil)
      byebug
      user_params = options.permit(:username, :full_name, :email, :gender, :dob, :uid, :oauth_provider, :picture_url,
        work: [:desig, :name, :location], education: [:degree, :name, :concentration],
        location: [:lat, :lng, :formatted_address])

      if  User.find_by(uid: options[:uid], oauth_provider: options[:oauth_provider])
        return :user_already_exists
      end

      if options[:otp]
        otp_check = EmailOtp.check_otp(options[:email], options[:otp])
        return otp_check unless otp_check == :valid
        return :auth_token_invalid  unless auth_info_valid?(options.slice(:uid, :auth_token, :oauth_provider))
      else
        return :email_invalid unless auth_info_valid?(options.slice(:email, :auth_token, :oauth_provider))
      end

      return sign_up_user(user_params, ip)
    end

    def sign_in(options)
      # check if auth(fb_or_google) credentials are valid
      unless auth_info_valid?(options.slice(:uid, :auth_token, :oauth_provider))
        return :auth_token_invalid
      end

      # check if  user exists?
      if  user =  User.find_by(uid: options[:uid], oauth_provider: options[:oauth_provider])
        #  user found and is not deactivated
        return  user
      else
        return :not_found
      end

    end

    def sign_up_user(options, ip = nil)
      byebug
      user_params = options.permit(:username, :full_name, :email, :gender, :uid, :oauth_provider)
      user =  User.new(user_params)
      user.session = Session.new
      return  user

    end

  end
end
