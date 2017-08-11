class Api::V2::BaseController < ActionController::Base
  include ApplicationHelper

  around_action :dev_env_debug, if: -> { Rails.env.development? }
  before_action :authenticate_api_user

  def authenticate_api_user

  end

  def current_api_user

  end

  def append_info_to_payload(payload)

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

  end

end
