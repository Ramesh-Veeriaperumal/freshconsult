class Group < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |g|
    g.add :id
    g.add :name
    g.add :description
    g.add :account_id
    g.add :email_on_assign
    g.add :escalate_to
    g.add :assign_time
    g.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    g.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
    g.add :import_id
    g.add :ticket_assign_type
    g.add :business_calendar_id
    g.add :toggle_availability
    g.add :capping_limit
  end
end