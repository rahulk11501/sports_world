class User < ActiveRecord::Base
  include UserAuth
  include ApplicationHelper

  has_one :session, dependent: :destroy
end
