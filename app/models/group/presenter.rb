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
    if self.agent_changes.present?
      agents = agent_groups.pluck :user_id
      changes = {added: [], removed: []}
      self.agent_changes.uniq.each do |ag|
        agents.include?(ag[:id]) ? changes[:added].push(ag) : 
                                   changes[:removed].push(ag)
      end
      if changes[:added].any? || changes[:removed].any?
        @model_changes.merge!({"agents" => changes})
      end
    end
    @model_changes
  end

  def relationship_with_account
    "groups"
  end
end
