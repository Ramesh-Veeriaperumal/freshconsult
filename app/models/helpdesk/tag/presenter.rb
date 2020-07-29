class Helpdesk::Tag < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |g|
    g.add :id
    g.add :name
    g.add :account_id
    g.add :tag_uses_count
  end

  def event_info action
    { :ip_address => Thread.current[:current_ip]}
  end

  def model_changes_for_central
    @model_changes
  end

  def relationship_with_account
    'tags'
  end
end