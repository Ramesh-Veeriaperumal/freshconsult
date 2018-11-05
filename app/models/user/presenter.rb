class User < ActiveRecord::Base
  include RepresentationHelper

  DATETIME_FIELDS = [:last_login_at, :current_login_at, :last_seen_at, :blocked_at, :deleted_at, :created_at, :updated_at]
  CONTACT_CREATE_DESTROY = ["contact_create", "contact_destroy"]
  AGENT_UPDATE = "agent_update"
  NEW_CONTACT = "agent_to_contact_conversion"
  NEW_AGENT = "contact_to_agent_conversion"

  acts_as_api

  api_accessible :central_publish do |u|
    u.add :id
    u.add :name
    u.add :agent_or_contact, as: :type
    u.add :email
    u.add :last_login_ip
    u.add :current_login_ip
    u.add :login_count
    u.add :failed_login_count
    u.add :account_id
    u.add :active
    u.add :customer_id
    u.add :job_title
    u.add :second_email
    u.add :phone
    u.add :mobile
    u.add :twitter_id
    u.add :description
    u.add :time_zone
    u.add :posts_count
    u.add :deleted
    u.add :user_role
    u.add :delta
    u.add :import_id
    u.add :fb_profile_id
    u.add :language
    u.add :blocked
    u.add :address
    u.add :whitelisted
    u.add :external_id
    u.add :preferences
    u.add :helpdesk_agent
    u.add :privileges
    u.add :extn
    u.add :parent_id
    u.add :unique_external_id
    DATETIME_FIELDS.each do |key|
      u.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end
  end

  def central_payload_type
    action = [:create, :update, :destroy].find{ |action| 
      transaction_include_action? action }
    return "contact_destroy" unless action.present?
    user_type = agent_or_contact
    if @model_changes.present? && @model_changes.key?("helpdesk_agent")
      action = @model_changes["helpdesk_agent"][0] ? "create" : "destroy"
      user_type = "contact"
    end
    "#{user_type}_#{action}"
  end

  def agent_or_contact
    helpdesk_agent ? 'agent' : 'contact'
  end

  def event_info action
    { :ip_address => Thread.current[:current_ip] }
  end

  def model_changes_for_central
    payload_type = central_payload_type
    return {} if CONTACT_CREATE_DESTROY.include?(payload_type) || 
                 payload_type == AGENT_UPDATE
    @model_changes
  end

  def misc_changes_for_central
    payload_type = central_payload_type
    if CONTACT_CREATE_DESTROY.include?(payload_type)
      key = CONTACT_CREATE_DESTROY[0] == payload_type ? 
        NEW_CONTACT : NEW_AGENT
      {"#{key}": true}
    end
  end

  def relationship_with_account
    "users"
  end

  def central_publish_worker_class
    "CentralPublishWorker::UserWorker"
  end
end
