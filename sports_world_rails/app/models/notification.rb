require 'elasticsearch/model'

class Notification < ActiveRecord::Base

  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  mappings do
   indexes :id
   indexes :notif_type
  end
end


