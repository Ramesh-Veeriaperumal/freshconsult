class Helpdesk::Ticket < ActiveRecord::Base
  include RepresentationHelper
  FLEXIFIELD_PREFIXES = ['ffs_', 'ff_text', 'ff_int', 'ff_date', 'ff_boolean', 'ff_decimal', 'dn_slt_', 'dn_mlt_'].freeze
  REPORT_FIELDS = [:first_assign_by_bhrs, :first_response_id, :first_response_group_id, :first_assign_agent_id, :first_assign_group_id, :agent_reassigned_count, :group_reassigned_count, :reopened_count, :private_note_count, :public_note_count, :agent_reply_count, :customer_reply_count, :agent_assigned_flag, :agent_reassigned_flag, :group_assigned_flag, :group_reassigned_flag, :internal_agent_assigned_flag, :internal_agent_reassigned_flag, :internal_group_assigned_flag, :internal_group_reassigned_flag, :internal_agent_first_assign_in_bhrs, :last_resolved_at].freeze
  NEW_REPORT_FIELDS = [:first_response_agent_id].freeze # Used for backfilling, can be removed once backfilling is complete
  EMAIL_KEYS = [:cc_emails, :fwd_emails, :bcc_emails, :reply_cc, :tkt_cc].freeze
  DATETIME_FIELDS = [:due_by, :closed_at, :resolved_at, :created_at, :updated_at, :first_response_time, :first_assigned_at].freeze
  TAG_KEYS = [:add_tag, :remove_tag].freeze
  WATCHER_KEYS = [:add_watcher, :remove_watcher].freeze
  SYSTEM_ACTIONS = [:add_comment, :add_a_cc, :email_to_requester, :email_to_group, :email_to_agent].freeze
  DONT_CARE_VALUE = '*'.freeze

  acts_as_api

  api_accessible :central_publish do |t|
    t.add :id
    t.add :display_id
    t.add :account_id
    t.add :responder_id
    t.add :group_id
    t.add :status_hash, as: :status
    t.add :priority_hash, as: :priority
    t.add :ticket_type
    t.add :source_hash, as: :source
    t.add :requester_id
    t.add :skill_id, :if => proc { Account.current.skill_based_round_robin_enabled? }
    t.add :custom_fields_hash, as: :custom_fields
    t.add :product_id, :if => proc { Account.current.multi_product_enabled? }
    t.add :company_id
    t.add :sla_policy_id
    t.add :association_type, :if => proc { Account.current.parent_child_tickets_enabled? || Account.current.link_tickets_enabled? }
    t.add :isescalated, as: :is_escalated
    t.add :fr_escalated
    t.add :resolution_time_by_bhrs, as: :time_to_resolution_in_bhrs
    t.add :resolution_time_by_chrs, as: :time_to_resolution_in_chrs
    t.add :inbound_count
    t.add :first_resp_time_by_bhrs, as: :first_response_by_bhrs
    t.add :archive, :if => proc { Account.current.features_included?(:archive_tickets) }
    t.add :internal_agent_id, :if => proc { Account.current.shared_ownership_enabled? }
    t.add :internal_group_id, :if => proc { Account.current.shared_ownership_enabled? }
    t.add :parent_ticket, as: :parent_id
    t.add :outbound_email?, as: :outbound_email
    t.add :subject
    t.add proc { |x| x.description }, as: :description_text
    t.add :description_html
    t.add :watchers
    t.add :urgent
    t.add :spam
    t.add :trained
    t.add proc { |x| x.utc_format(x.frDueBy) }, as: :fr_due_by
    t.add :to_emails
    t.add :email_config_id
    t.add :deleted
    t.add :group_users
    t.add :import_id
    t.add proc { |x| x.tags.collect { |tag| { id: tag.id, name: tag.name } } }, as: :tags
    REPORT_FIELDS.each do |key|
      t.add proc { |x| x.reports_hash[key.to_s] }, as: key
    end
    NEW_REPORT_FIELDS.each do |key|
      t.add proc { |x| x.safe_send(key) }, as: key
    end
    DATETIME_FIELDS.each do |key|
      t.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
    EMAIL_KEYS.each do |key|
      t.add proc { |x| x.cc_email_hash.try(:[], key) }, as: key
    end
  end

  api_accessible :central_publish_associations do |t|
    t.add :requester, template: :central_publish
    t.add :responder, template: :central_publish
    t.add :group, template: :central_publish
  end

  api_accessible :central_publish_destroy do |t|
    t.add :id
    t.add :display_id
    t.add :account_id
    t.add :archive
  end

  def central_payload_type
    if import_ticket && import_id.present?
      action = [:create, :update].find{ |action| transaction_include_action? action }
      "import_ticket_#{action}" if action.present?
    end
  end

  def action_in_bhrs?
    BusinessCalendar.execute(self) do
      action_occured_in_bhrs?(Time.zone.now, group)
    end
  end

  def priority_hash
    { 
      id: priority, 
      name: PRIORITY_NAMES_BY_KEY[priority]
    }
  end

  def status_hash
    { 
      id: status, 
      name: status_name
    }
  end

  def source_hash
    { 
      id: source, 
      name: SOURCE_NAMES_BY_KEY[source]
    }
  end

  def custom_fields_hash
    custom_ticket_fields.inject([]) do |arr, field|
      begin
        field_value = safe_send(field.name)
        arr.push({
          ff_alias: field.flexifield_def_entry.flexifield_alias,
          ff_name: field.flexifield_def_entry.flexifield_name,
          ff_coltype: field.flexifield_def_entry.flexifield_coltype,
          field_value: field.field_type == 'custom_date' ? utc_format(field_value) : field_value
        })
      rescue Exception => e
        Rails.logger.error "Error while fetching ticket custom field value - #{e}\n#{e.message}\n#{e.backtrace.join("\n")}"
        NewRelic::Agent.notice_error(e)
      end
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

  def column_attribute_mapping
    Helpdesk::SchemaLessTicket::COLUMN_TO_ATTRIBUTE_MAPPING.merge({
      sl_skill_id: :skill_id,
      owner_id: :company_id
    })
  end

  def model_changes_for_central
    changes = transformed_model_changes.with_indifferent_access
    # SchemaLessTicket has columns like text_tc01 that need to be renamed
    column_attribute_mapping.each_pair do |key, val| 
      changes[val] = changes.delete(key) if changes.key?(key)
    end
    changes[:description] = [nil, DONT_CARE_VALUE] if description_content_changed?
    # Handling changes to custom_fields - flexifield name should be replaced with flexifield alias
    flexifield_changes = changes.select { |k, v| k.to_s.starts_with?(*FLEXIFIELD_PREFIXES) }
    return changes if flexifield_changes.blank?
    flexifield_changes.each_pair do |key, val|
      changes[custom_field_name_mapping[key.to_s]] = val
    end
    changes.except(*flexifield_changes.keys)
  end

  def system_changes_for_central
    # Tranforming system_changes from
    # { 
    #    "20" => { rule: ['observer', 'abc'], priority: [nil, 3], add_tag: 'test' },
    #    "25" => { rule: ['observer', 'xyz'], add_tag: 'new', add_watcher: [11], send_email_to_agent: [6] }
    # } to
    # [
    #   { id: 20, type: 'observer', name: 'abc', model_changes: { priority: [nil, 3], tags: { added: ['test'], removed: [] } } },
    #   { id: 25, type: 'observer', name: 'xyz', model_changes: { tags: { added: ['new'], removed: [] } }, actions: { send_email_to_agent: [6] } }
    # ]
    Array.new.tap do |changeset|
      (@system_changes || {}).each do |rule_id, info|
        changes = info.except(:rule, *SYSTEM_ACTIONS)
        changeset << {
          id: rule_id,
          type: info[:rule][0],
          name: info[:rule][1],
          model_changes: changes.merge(transform_array_fields(changes)).except(*TAG_KEYS, *WATCHER_KEYS),
          actions: info.slice(*SYSTEM_ACTIONS)
        }
      end
    end
  end

  def misc_changes_for_central
    (self.misc_changes || {}).except(*TAG_KEYS, *WATCHER_KEYS, :misc_changes)
  end

  def transformed_model_changes
    # misc_changes contain updates to tag if added/removed by user
    # system_changes contain updates to tag and watcher if added/removed by system
    changes = @system_changes.present? ? system_changes_to_array_fields : self.misc_changes
    (@model_changes || {}).merge(transform_array_fields(changes))
  end

  def system_changes_to_array_fields
    Hash.new.tap do |merged_set|
      (@system_changes || {}).each do |rule_id, info|
        changes = info.slice(*TAG_KEYS, *WATCHER_KEYS)
        changes.each do |key, arr|
          merged_set.key?(key) ? merged_set[key] |= arr : merged_set[key] = arr
        end
      end
    end
  end

  # Transforming tags and watcher fields from
  # { add_tag: ['abc'], remove_watcher: [5] } to
  # { tags: { added: ['abc'], removed: [] }, watchers: { added: [], removed: [5] } }
  def transform_array_fields(changes)
    transformed_changes = {}
    if (changes.try(:keys) & TAG_KEYS).present?
      transformed_changes[:tags] = {}
      transformed_changes[:tags][:added] = changes[:add_tag] || []
      transformed_changes[:tags][:removed] = changes[:remove_tag] || []
    end
    if (changes.try(:keys) & WATCHER_KEYS).present?
      transformed_changes[:watchers] = {}
      transformed_changes[:watchers][:added] = changes[:add_watcher] || []
      transformed_changes[:watchers][:removed] = changes[:remove_watcher] || []
    end
    transformed_changes
  end

  def description_content_changed?
    [*ticket_old_body.previous_changes.keys, *(@model_changes || {}).keys.map(&:to_s)].include?('description')
  end

  def custom_field_name_mapping
    @flexifield_name_mapping ||= begin
      Account.current.flexifields_with_ticket_fields_from_cache.each_with_object({}) { |ff_def_entry, hash| hash[ff_def_entry.flexifield_name] = ff_def_entry.flexifield_alias }
    end
  end

  def event_info(event_name)
    return   {pod: ChannelFrameworkConfig['pod']} if event_name == 'destroy'
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
