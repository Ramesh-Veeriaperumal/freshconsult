class Helpdesk::NestedTicketField < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :base do |ntf|
    ntf.add :label
    ntf.add :label_in_portal
    ntf.add :description
    ntf.add :level
    ntf.add proc { |t| t.utc_format(t.created_at) }, as: :created_at
    ntf.add proc { |t| t.utc_format(t.updated_at) }, as: :updated_at
  end

  api_accessible :central_publish, extend: :base do |ntf|
    ntf.add :id
    ntf.add :name
  end

  api_accessible :api, extend: :base do |nested_field|
    nested_field.add proc { |obj| TicketDecorator.display_name(obj.name) }, as: :name
    nested_field.add :ticket_field_id
  end
end
