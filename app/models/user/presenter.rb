class User < ActiveRecord::Base
  include RepresentationHelper
  include CustomFieldsHelper

  DATETIME_FIELDS = [:last_login_at, :current_login_at, :last_seen_at, :blocked_at, :deleted_at, :created_at, :updated_at]
  CONTACT_CREATE_DESTROY = ["contact_create", "contact_destroy"]
  FLEXIFIELD_PREFIXES = %w[cf_str cf_date cf_text cf_int cf_boolean].freeze
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
    u.add :import_id
    u.add :company_id
    u.add proc { |x| x.tags.collect { |tag| { id: tag.id, name: tag.name } } }, as: :tags
    u.add proc { |x| x.user_emails.where(primary_role: false).pluck(:email) }, as: :other_emails
    u.add proc { |x| x.user_companies.where(default: false).pluck(:company_id) }, as: :other_company_ids
    u.add proc { |x| x.custom_field_hash('contact') }, as: :custom_fields, unless: proc { |t| t.helpdesk_agent? }
    DATETIME_FIELDS.each do |key|
      u.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end
  end

  api_accessible :central_publish_associations do |u|
    u.add :companies, template: :central_publish
  end

  api_accessible :internal_agent_central_publish_associations do |t|
    t.add :id
    t.add :name
    t.add :agent_or_contact, as: :type
    t.add :email
    t.add :account_id
    t.add :active
  end

  api_accessible :widget do |u|
    u.add :id
    u.add :name
    u.add :email
    u.add :phone
    u.add :mobile
    u.add :language
    u.add :external_id
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
    import_id.present? ? "import_#{user_type}_#{action}" : "#{user_type}_#{action}"
  end

  def agent_or_contact
    helpdesk_agent ? 'agent' : 'contact'
  end

  def event_info(action)
    { ip_address: Thread.current[:current_ip], app_update: valid_app_event?(action) }
  end

  def model_changes_for_central
    payload_type = central_payload_type
    return {} if CONTACT_CREATE_DESTROY.include?(payload_type) || payload_type == AGENT_UPDATE

    changes = (@model_changes || {}).clone
    changes = changes.merge(tags: tag_update_model_changes) if self.tags_updated
    flexifield_changes = changes.select { |k, v| k.to_s.starts_with?(*FLEXIFIELD_PREFIXES) }
    return changes if flexifield_changes.blank?

    contact_cf_name_mapping = account.contact_form.contact_fields_from_cache.each_with_object({}) { |entry, hash| hash[entry.column_name] = entry.name }
    flexifield_changes.each_pair do |key, val|
      changes[contact_cf_name_mapping[key.to_s]] = val
      changes.delete(key)
    end
    changes
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
    "all_users"
  end

  def central_publish_worker_class
    "CentralPublishWorker::UserWorker"
  end
end
