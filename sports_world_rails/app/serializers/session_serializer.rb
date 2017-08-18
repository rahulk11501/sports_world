class SessionSerializer < ActiveModel::Serializer

	# attributes :access_token, :user
  attributes :access_token, :queue_name

  def queue_name
  	nil
  end

end
