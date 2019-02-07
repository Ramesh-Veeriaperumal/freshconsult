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
    g.add :group_type
    g.add proc { |x| x.utc_format(x.created_at) }, as: :created_at
    g.add proc { |x| x.utc_format(x.updated_at) }, as: :updated_at
    g.add :import_id
    g.add :ticket_assign_type
    g.add :business_calendar_id
    g.add :toggle_availability
    g.add :capping_limit
    g.add proc { |x| x.agents.map { |ag| {name: ag.name, id: ag.id }}}, as: :agents
  end

  api_accessible :central_publish_associations do |t|
    t.add :business_calendar, template: :central_publish
  end
  
  api_accessible :central_publish_destroy do |t|
    t.add :id
    t.add :account_id   
  end

  def event_info action
    { :ip_address => Thread.current[:current_ip] }
  end

  def model_changes_for_central
    if Thread.current[:agent_changes].present?
      agents = agent_groups.pluck :user_id
      agent_changes = {added: [], removed: []}
      Thread.current[:agent_changes].uniq.each do |ag|
        agents.include?(ag[:id]) ? agent_changes[:added].push(ag) : 
                                   agent_changes[:removed].push(ag)
      end
      if agent_changes[:added].any? || agent_changes[:removed].any?
        @model_changes.merge!({"agents" => agent_changes})
      end
      Thread.current[:agent_changes] = nil
    end
    @model_changes
  end

  def relationship_with_account
    "groups"
  end
end
