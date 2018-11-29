class Helpdesk::NestedTicketField < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |ntf|
    ntf.add :id
    ntf.add :name
    ntf.add :label
    ntf.add :label_in_portal
    ntf.add :description
    ntf.add :level
    ntf.add proc { |t| t.utc_format(t.created_at) }, as: :created_at
    ntf.add proc { |t| t.utc_format(t.updated_at) }, as: :updated_at
  end

end
