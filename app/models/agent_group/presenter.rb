class AgentGroup < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at]


  acts_as_api

  api_accessible :central_publish do |g|
    g.add :id
    g.add :user_id
    g.add :group_id
    g.add :account_id

    DATETIME_FIELDS.each do |key|
      g.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end

  end

  def self.central_publish_enabled?
    Account.current.agent_group_central_publish_enabled?
  end

  def event_info action
    { :ip_address => Thread.current[:current_ip]}
  end

  def model_changes_for_central
    @model_changes
  end

  def relationship_with_account
    'agent_groups'
  end
end