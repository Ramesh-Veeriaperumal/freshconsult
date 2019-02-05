class BusinessCalendar < ActiveRecord::Base
  acts_as_api

  api_accessible :central_publish do |t|
    t.add :name
    t.add :description
    t.add :time_zone
    t.add :is_default
  end
end
