class Integrations::Application < ActiveRecord::Base
  
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |t|
    t.add :id
    t.add :name
    t.add :display_name
    t.add :description
  end

end