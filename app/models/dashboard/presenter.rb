class Dashboard < ActiveRecord::Base
  include RepresentationHelper

  ALL_AGENTS = 0

  acts_as_api

  api_accessible :central_publish do |d|
    d.add :id
    d.add :name
    d.add :account_id
    d.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    d.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
    d.add :groups, template: :dashboard_group_central_publish
    d.add proc { |x| x.access_type == ALL_AGENTS }, as: :all_agents
  end
end
