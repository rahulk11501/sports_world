class Api::V2::BaseController < ActionController::Base
  include ApplicationHelper

  around_action :dev_env_debug, if: -> { Rails.env.development? }
  before_action :authenticate_api_user

  def authenticate_api_user
    if @session||= Session.find_by(access_token: request.headers['X-Token'])
      if !(current_api_user)
        render json: { errors: 'User not found' }, status: 404
      elsif @session.expires_at < Time.now
        render json: { errors: 'Session Expired'}, status: 401
      end
      return true
    else
      render json: {errors: "Invalid Access Token"}, status: 401
    end
  end

  def current_api_user
    if @session
      @current_user ||= User.find_by(id: @session.user_id, active: true)
    else
      nil
    end
  end

  def append_info_to_payload(payload)
    super
    payload[:remote_ip]     = (request.headers['X-Forwarded-For'] || request.remote_ip).split(',')[0]
    payload[:user]          = current_api_user.id rescue nil
    payload[:url]           = request.url
    payload[:amzn_trace_id] = request.headers['X-AMZN-TRACE-ID']
    payload[:device_type]   = request.headers['X-Device']
    payload[:app_version]   = request.headers['X-Version']
    payload[:user_agent]    = request.user_agent

    # common_headers = %w{VERSION ACCEPT_LANGUAGE ACCEPT_ENCODING DNT ACCEPT USER_AGENT X_TOKEN CACHE_CONTROL CONNECTION HOST}

    # payload[:extra_headers] = request.headers.to_a.
    #   select{ |h| h[0].starts_with?("HTTP_") }.
    #   map   { |h| { h[0][5..-1] => h[1] } }.
    #   reject{ |h| common_headers.include?(h.keys[0]) }
  end

  def is_android?
    request.headers['X-Device'].to_s.parameterize.include? 'android'
  end
  def is_ios?
    request.headers['X-Device'].to_s.parameterize.include? 'android'
  end
  def app_ver
    request.headers['X-Version'].to_i
  end
  def before_android_nearby_release
    is_android? && app_ver < APP_CONFIG['nearby_android_base_ver']
  end

  def dev_env_debug
    puts("\n\n\n\n\n\n--------------------------------------------")

    # log requests to /tmp/aa
    q= File.open('/tmp/aa', 'a')
    if current_api_user
      current_user = "#{current_api_user.id} - #{current_api_user}"
    else
      current_user = nil
    end
    q.write( Time.now.strftime("%Y-%m-%d %H:%M:%S.%6N") + " (#{current_user}) (#{request.ip}) -> " + request.url + "\n" )
    q.close

    puts("\n"                                           + \
      "\n#{Time.now.strftime("%Y-%m-%d %H:%M:%S.%6N")}" + \
      "\n--------------------------------------------"  + \
      "\nRequest Method: #{request.method}"             + \
      "\nRequest IP: #{request.ip}"                     + \
      "\nRequest URL: #{request.path}"                  + \
      "\nRequest URL with params: #{request.url.split(request.base_url)[1]}"+ \
      "\nAccess Token: #{request.headers['X-Token']}"   + \
      "\nURL-Params: #{request.query_parameters}"       + \
      "\nPOST-Body-Params: #{request.body.read}"        + \
      "\n----------")

    yield

    res = response.body.first(500)
    if res.length == 500
      res = res + "..."
      res = res.gsub(/(.{80})(?=.)/, "\\1\n\t\\2")
    end

    puts(
      "----------"                                        + \
      "\nStatus Code: #{response.status}"                 + \
      "\nResponse Body:\n\t#{res}"                        + \
      "\n--------------------------------------------\n"  + \
      "\n\n")
  end

end
