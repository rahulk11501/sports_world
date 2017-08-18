class Session < ActiveRecord::Base
  belongs_to :user

  validates :access_token, uniqueness: true

  before_create :generate_access_token

  def generate_access_token(type = nil)
    duration = 100.days
    begin
      self.access_token = SecureRandom.hex
    end while self.class.exists?(access_token: access_token)
    self.expires_at = Time.zone.now + duration
    self.device_type ||= type.try(:downcase)
  end

  def expired?
    expires_at < DateTime.current
  end
end
