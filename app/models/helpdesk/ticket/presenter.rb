class Helpdesk::Ticket < ActiveRecord::Base
  include RepresentationHelper
  MAX_DESC_LIMIT = 10000
  FLEXIFIELD_PREFIXES = ['ffs_', 'ff_text', 'ff_int', 'ff_date', 'ff_boolean', 'ff_decimal']
  REPORT_FIELDS = [:first_assign_by_bhrs, :first_response_id, :agent_reassigned_count, :group_reassigned_count, :reopened_count, :private_note_count, :public_note_count, :agent_reply_count, :customer_reply_count, :reopened_count, :agent_assigned_flag, :agent_reassigned_flag, :group_assigned_flag, :group_reassigned_flag, :internal_agent_assigned_flag, :internal_agent_reassigned_flag, :internal_group_assigned_flag, :internal_group_reassigned_flag, :internal_agent_first_assign_in_bhrs, :last_resolved_at]
  EMAIL_KEYS = [:cc_emails, :fwd_emails, :bcc_emails, :reply_cc, :tkt_cc]
  DATETIME_FIELDS = [:due_by, :closed_at, :resolved_at, :created_at, :updated_at]
  DONT_CARE_VALUE = "*"

  acts_as_api

  api_accessible :central_publish do |t|
    t.add :id
    t.add :display_id
    t.add :account_id
    t.add :responder_id
    t.add :group_id
    t.add :status_hash, as: :status
    t.add :priority
    t.add :ticket_type
    t.add :source
    t.add :requester_id
    t.add :sl_skill_id, :if => proc { Account.current.skill_based_round_robin_enabled? }
    t.add :custom_fields_hash, as: :custom_fields
    t.add :product_id, :if => proc { Account.current.multi_product_enabled? }
    t.add :company_id
    t.add :sla_policy_id
    t.add :association_type, :if => proc { Account.current.parent_child_tkts_enabled? || Account.current.link_tkts_enabled? }
    t.add :isescalated, as: :is_escalated
    t.add :fr_escalated
    t.add :resolution_time_by_bhrs, as: :time_to_resolution_in_bhrs
    t.add :resolution_time_by_chrs, as: :time_to_resolution_in_chrs
    t.add :inbound_count
    t.add :first_resp_time_by_bhrs, as: :first_response_by_bhrs
    t.add :archive, :if => proc { Account.current.features_included?(:archive_tickets) }
    t.add :internal_agent_id, :if => proc { Account.current.shared_ownership_enabled? }
    t.add :internal_group_id, :if => proc { Account.current.shared_ownership_enabled? }
    t.add :parent_ticket_id, as: :parent_id
    t.add :outbound_email?, as: :outbound_email
    t.add :subject
    t.add :requester, template: :central_publish
    t.add proc { |x| x.truncate_description }, as: :description_text
    t.add proc { |x| x.description.length > MAX_DESC_LIMIT }, as: :description_text_truncated
    t.add proc { |x| x.truncate_description(true) }, as: :description_html
    t.add proc { |x| x.description_html.length > MAX_DESC_LIMIT }, as: :description_html_truncated
    t.add :responder, template: :central_publish
    t.add :watchers, as: :subscribers
    t.add :attachments
    t.add :urgent
    t.add :spam
    t.add :trained
    t.add :frDueBy, as: :fr_due_by
    t.add :to_emails
    t.add :email_config_id
    t.add :deleted
    t.add :group, template: :central_publish
    t.add :group_users
    t.add proc { |x| x.tags.collect { |tag| { id: tag.id, name: tag.name } } }, as: :tags
    REPORT_FIELDS.each do |key|
      t.add proc { |x| x.reports_hash[key.to_s] }, as: key
    end
    EMAIL_KEYS.each do |key|
      t.add proc { |x| x.cc_email.try(:[], key) }, as: key
    end
    DATETIME_FIELDS.each do |key|
      t.add proc { |x| x.utc_format(x.send(key)) }, as: key
    end
  end

  def truncate_description(html = false)
    (html ? description_html : description).truncate(MAX_DESC_LIMIT)
  end

  def action_in_bhrs?
    BusinessCalendar.execute(self) do
      action_occured_in_bhrs?(Time.zone.now, group)
    end
  end

  def status_hash
    {
      id: status,
      name: status_name
    }
  end

  def custom_fields_hash
    custom_ticket_fields.inject([]) do |arr, field|
      field_value = send(field.name)
      arr.push({
        ff_alias: field.flexifield_def_entry.flexifield_alias,
        ff_name: field.flexifield_def_entry.flexifield_name,
        ff_coltype: field.flexifield_def_entry.flexifield_coltype,
        field_value: field.field_type == 'custom_date' ? utc_format(field_value) : field_value
      })
    end
  end

  def custom_ticket_fields
    @custom_tkt_fields ||= account.ticket_fields_from_cache.reject(&:default)
  end

  def resolution_time_by_chrs
    resolved_at ? (resolved_at - created_at) : nil
  end

  def group_users
    return [] unless group
    agents_group = Account.current.agent_groups_from_cache.select { |x| x.group_id == group.id }
    agents_group.collect { |user| { "id" => user.id } }
  end

  # *****************************************************************
  # METHODS USED BY CENTRAL PUBLISHER GEM. NOT A PART OF PRESENTER
  # *****************************************************************

  def self.central_publish_enabled?
    Account.current.ticket_central_publish_enabled?
  end

  def model_changes_for_central
    changes = (@model_changes || {}).except(:tags).merge(self.misc_changes || {})
    description_changed = [*ticket_old_body.previous_changes.keys, *changes.keys.map(&:to_s)].include?('description')
    changes[:description] = [nil, DONT_CARE_VALUE] if description_changed
    flexifield_changes = changes.select { |k, v| k.to_s.starts_with?(*FLEXIFIELD_PREFIXES) }
    return changes if flexifield_changes.blank?
    cf_changes = {}
    flexifield_changes.each_pair do |key, val|
      cf_changes.merge!(custom_field_name_mapping[key.to_s] => val)
    end
    changes.except(*flexifield_changes.keys).merge(custom_fields: cf_changes)
  end

  def system_changes_for_central
    changes = []
    (@system_changes || {}).each do |rule_id, info|
      changes << {
        id: rule_id,
        type: info[:rule][0],
        name: info[:rule][1],
        changes: info.except(:rule)
      }
    end
    changes
  end

  def custom_field_name_mapping
    @flexifield_name_mapping ||= begin
      Account.current.flexifields_with_ticket_fields_from_cache.each_with_object({}) { |ff_def_entry, hash| hash[ff_def_entry.flexifield_name] = ff_def_entry.flexifield_alias }
    end
  end

  def event_info(event_name)
    lifecycle_hash = (event_name == 'create' && resolved_at) ? default_lifecycle_properties : (@ticket_lifecycle || {})
    { action_in_bhrs: action_in_bhrs? }.merge(lifecycle_hash)
  end

  def default_lifecycle_properties
    {
      action_time_in_bhrs: 0,
      action_time_in_chrs: 0,
      chrs_from_tkt_creation: 0
    }
  end

  def central_publish_worker_class
    "CentralPublishWorker::#{Account.current.subscription.state.titleize}TicketWorker"
  end
end
