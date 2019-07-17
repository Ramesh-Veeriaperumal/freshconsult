class Agent < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:created_at, :updated_at, :active_since, :last_active_at]
  USER_FIELDS = [:name, :email, :last_login_ip, :current_login_ip, :login_count, 
    :failed_login_count, :active, :customer_id, :job_title, :second_email, 
    :phone, :mobile, :twitter_id, :description, :time_zone, :posts_count, :deleted, 
    :user_role, :delta, :import_id, :fb_profile_id, :language, :blocked, :address, 
    :whitelisted, :external_id, :preferences, :helpdesk_agent, :privileges, :extn, 
    :parent_id, :unique_external_id, :last_login_at, :current_login_at, :last_seen_at, 
    :blocked_at, :deleted_at]

  AGENT_LOGGEDIN_ACTION = [:logged_in].freeze
  acts_as_api

  api_accessible :central_publish do |s|
    s.add :id
    s.add :user_id
    s.add :signature
    s.add :ticket_permission_hash, as: :ticket_permission
    s.add :occasional
    s.add :google_viewer_id
    s.add :signature_html
    s.add :points
    s.add :scoreboard_level_id
    s.add :account_id
    s.add :available
    s.add :agent_type_hash, as: :agent_type
    s.add proc { |x| x.groups.map { |ag| {name: ag.name, id: ag.id }}}, as: :groups
    USER_FIELDS.each do |key|
      s.add proc { |d| d.user.safe_send(key) }, as: key
    end
    DATETIME_FIELDS.each do |key|
      s.add proc { |d| d.utc_format(d.safe_send(key)) }, as: key
    end
  end

  def event_info action
    { :ip_address => Thread.current[:current_ip] }
  end

  def model_changes_for_central
    return {} if login_logout_action?
    changes = @model_changes.merge(self.user_changes || {})
    changes.merge!({
      "single_access_token" => ["*", "*"]
    }) if @model_changes.key?("single_access_token")
    if self.group_changes.present?
      groups = agent_groups.pluck :group_id
      groups_hash = {added: [], removed: []}
      self.group_changes.uniq.each do |ag|
        groups.include?(ag[:id]) ? groups_hash[:added].push(ag) : 
                                   groups_hash[:removed].push(ag)
      end
      if groups_hash[:added].any? || groups_hash[:removed].any?
        changes.merge!({"groups" => groups_hash})
      end
    end
    changes
  end

  def misc_changes_for_central
    login_logout_action? ? @misc_changes : {}
  end

  def current_user_id_for_central
    user_id if login_logout_action?
  end

  def relationship_with_account
    "all_agents"
  end

  def central_publish_worker_class
    "CentralPublishWorker::UserWorker"
  end

  def ticket_permission_hash
    {
      id: ticket_permission,
      permission: PERMISSION_TOKENS_BY_KEY[ticket_permission].to_s
    }
  end

  def agent_type_hash
    {
      id: agent_type,
      name: AgentType.agent_type_name(agent_type)
    }
  end

  def login_logout_action?
    unless @misc_changes.nil?
      return @misc_changes.key?(AGENT_LOGGEDIN_ACTION[0])? true : false
    end
    false
  end
end
