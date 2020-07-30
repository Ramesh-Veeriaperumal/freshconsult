class Helpdesk::TagUse < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |g|
    g.add :id
    g.add :tag_id
    g.add :account_id
    g.add :taggable_id
    g.add :taggable_type

  end

  def event_info action
    { :ip_address => Thread.current[:current_ip]}
  end

  def model_changes_for_central
    @model_changes
  end

  def relationship_with_account
    'tag_uses'
  end
end