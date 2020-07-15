class Helpdesk::Ticket < ActiveRecord::Base
  include RepresentationHelper
  include TicketsNotesHelper

  SECURE_FIELD_PREFIX = Admin::TicketFieldConstants::ENCRYPTED_FIELDS_PREFIX_BY_TYPE[:secure_text].freeze
  FLEXIFIELD_PREFIXES = (['ffs_', 'ff_text', 'ff_int', 'ff_date', 'ff_boolean', 'ff_decimal', 'dn_slt_', 'dn_mlt_'] | [SECURE_FIELD_PREFIX]).freeze
  REPORT_FIELDS = [:first_assign_by_bhrs, :first_response_id, :first_response_group_id, :first_response_agent_id,
                   :first_assign_agent_id, :first_assign_group_id, :agent_reassigned_count, :group_reassigned_count,
                   :reopened_count, :private_note_count, :public_note_count, :agent_reply_count, :customer_reply_count,
                   :agent_assigned_flag, :agent_reassigned_flag, :group_assigned_flag, :group_reassigned_flag,
                   :internal_agent_assigned_flag, :internal_agent_reassigned_flag, :internal_group_assigned_flag,
                   :internal_group_reassigned_flag, :internal_agent_first_assign_in_bhrs, :last_resolved_at].freeze
  EMAIL_KEYS = [:cc_emails, :fwd_emails, :bcc_emails, :reply_cc, :tkt_cc].freeze
  DATETIME_FIELDS = [:due_by, :closed_at, :resolved_at, :created_at, :updated_at, :first_response_time, :first_assigned_at].freeze
  TAG_KEYS = [:add_tag, :remove_tag].freeze
  WATCHER_KEYS = [:add_watcher, :remove_watcher].freeze
  SYSTEM_ACTIONS = [:add_comment, :add_a_cc, :email_to_requester, :email_to_group, :email_to_agent, :add_note, :forward_ticket].freeze
  DONT_CARE_VALUE = '*'.freeze
  SPLIT_TICKET_ACTIVITY = 'ticket_split_target'.freeze
  MERGE_TICKET_ACTIVITY = 'ticket_merge_source'.freeze
  ROUND_ROBIN_ACTIVITY = 'round_robin'.freeze
  SLA_FIELDS = [:boolean_tc04, :boolean_tc05, :nr_reminded, :int_tc02, :fr_escalated, :nr_escalated].freeze

  SLA_ATTRIBUTES = [
    [:resolution,    :int_tc02, :boolean_tc05],
    [:response,      :fr_escalated, :boolean_tc04],
    [:next_response, :nr_escalated, :nr_reminded]
  ].freeze

  SLA_ESCALATION_ATTRIBUTES = Hash[*SLA_ATTRIBUTES.map { |i| [i[0], i[1]] }.flatten]
  SLA_REMINDER_ATTRIBUTES = Hash[*SLA_ATTRIBUTES.map { |i| [i[0], i[2]] }.flatten]

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
    t.add :central_custom_fields_hash, as: :custom_fields
    t.add :product_id
    t.add :company_id
    t.add :sla_policy_id
    t.add :association_hash, as: :associates
    t.add :associates_rdb
    t.add :isescalated, as: :is_escalated
    t.add :fr_escalated
    t.add :nr_escalated, :if => proc { Account.current.next_response_sla_enabled? }
    t.add :escalation_level, as: :resolution_escalation_level
    t.add :sla_response_reminded, as: :response_reminded
    t.add :sla_resolution_reminded, as: :resolution_reminded
    t.add :nr_reminded, as: :next_response_reminded, :if => proc { Account.current.next_response_sla_enabled? }
    t.add :resolution_time_by_bhrs, as: :time_to_resolution_in_bhrs
    t.add :resolution_time_by_chrs, as: :time_to_resolution_in_chrs
    t.add :inbound_count
    t.add :first_resp_time_by_bhrs, as: :first_response_by_bhrs
    t.add :archive
    t.add :internal_agent_id
    t.add :internal_group_id
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
    t.add proc { |x| x.utc_format(x.nr_due_by) }, as: :nr_due_by, :if => proc { Account.current.next_response_sla_enabled? }
    t.add :to_emails
    t.add :email_config_id
    t.add :deleted
    t.add :group_users
    t.add :import_id
    t.add :on_state_time
    t.add proc { |x| x.attachments.map(&:id) }, as: :attachment_ids
    t.add proc { |x| x.tags.collect { |tag| { id: tag.id, name: tag.name } } }, as: :tags
    REPORT_FIELDS.each do |key|
      t.add proc { |x| x.reports_hash[key.to_s] }, as: key
    end
    DATETIME_FIELDS.each do |key|
      t.add proc { |x| x.utc_format(x.safe_send(key)) }, as: key
    end
    EMAIL_KEYS.each do |key|
      t.add proc { |x| x.cc_email_hash.try(:[], key) }, as: key
    end
    # Source additional info
    t.add :source_additional_info_hash, as: :source_additional_info
  end

  api_accessible :central_publish_associations do |t|
    t.add :requester, template: :central_publish
    t.add :responder, template: :central_publish
    t.add :group, template: :central_publish
    t.add :attachments, template: :central_publish
    t.add :skill, template: :skill_as_association, :if => proc { Account.current.skill_based_round_robin_enabled? }
    t.add :product, template: :product_as_association
    t.add :internal_group, template: :internal_group_central_publish_associations, if: proc { Account.current.shared_ownership_enabled? }
    t.add :internal_agent, template: :internal_agent_central_publish_associations, if: proc { Account.current.shared_ownership_enabled? }
  end

  api_accessible :central_publish_destroy do |t|
    t.add :id
    t.add :display_id
    t.add :account_id
    t.add :archive
    t.add :source_hash, as: :source
    t.add :ticket_type
  end

  def central_payload_type
    if import_ticket && import_id.present?
      action = [:create, :update].find{ |action| transaction_include_action? action }
      "import_ticket_#{action}" if action.present?
    end
  end

  def central_publish_payload
    as_api_response(:central_publish)
  end

  def central_publish_associations
    as_api_response(:central_publish_associations)
  end

  def relationship_with_account
    'tickets'
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
      name: Account.current.helpdesk_sources.ticket_source_names_by_key[source]
    }
  end

  def source_additional_info_hash
    source_info = {}
    source_info = social_source_additional_info(source_info)
    source_info[:email] = email_source_info(schema_less_ticket.header_info) if email_ticket?
    source_info.presence
  end

  def association_hash
    render_assoc_hash(association_type)
  end

  def render_assoc_hash(current_association_type)
    return nil if current_association_type.blank?

    {
      id: current_association_type,
      type: TICKET_ASSOCIATION_TOKEN_BY_KEY[current_association_type]
    }
  end

  def requester_twitter_id
    requester.try(:twitter_id)
  end

  def requester_fb_id
    requester.try(:fb_profile_id)
  end

  def association_hash
    render_assoc_hash(association_type)
  end

  def render_assoc_hash(current_association_type)
    return nil if current_association_type.blank?

    {
      id: current_association_type,
      type: TICKET_ASSOCIATION_TOKEN_BY_KEY[current_association_type]
    }
  end

  def central_custom_fields_hash
    pv_transformer = Helpdesk::Ticketfields::PicklistValueTransformer::StringToId.new(self)
    arr = []
    custom_flexifield_def_entries.each do |flexifield_def_entry|
      field = flexifield_def_entry.ticket_field
      next if field.blank?

      begin
        field_value = safe_send(field.name)
        custom_field = {
          name: field.name,
          label: field.label,
          type: field.flexifield_coltype,
          value: map_field_value(field, field_value),
          column: field.column_name
        }
        if field.flexifield_coltype == 'dropdown'
          if field_value
            picklist_id = pv_transformer.transform(field_value, field.column_name) # fetch picklist_id of the field
            custom_field[:value] = nil if picklist_id.blank?
          end
          custom_field[:choice_id] = picklist_id
        end
        custom_field[:value] = DONT_CARE_VALUE if field.field_type == TicketFieldsConstants::SECURE_TEXT && custom_field[:value].present?
        arr.push(custom_field)
      rescue Exception => e
        Rails.logger.error("Error while fetching ticket custom field #{field.name} - account #{account.id} - #{e.message} :: #{e.backtrace[0..10].inspect}")
        NewRelic::Agent.notice_error(e)
      end
    end
    arr
  end

  def map_field_value(ticket_field, value)
    if ticket_field.field_type == 'custom_date'
      utc_format(value)
    elsif ticket_field.field_type == 'custom_file' && value.present?
      value.to_i
    else
      value
    end
  end

  def custom_flexifield_def_entries
    @custom_flexifield_def_entries ||= account.flexifields_with_ticket_fields_from_cache
  end

  def custom_ticket_fields
    @custom_tkt_fields ||= account.ticket_fields_from_cache.reject(&:default)
  end

  def file_ticket_fields
    custom_ticket_fields.select { |x| x.field_type == 'custom_file' }.map(&:column_name)
  end

  def resolution_time_by_chrs
    resolved_at ? (resolved_at - created_at) : nil
  end

  def group_users
    return [] unless group
    group_users = Account.current.agent_groups_hash_from_cache[group.id]
    (group_users && group_users.collect { |user_id| { "id" => user_id } }) || []
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
      owner_id: :company_id,
      boolean_tc04: :response_reminded,
      boolean_tc05: :resolution_reminded,
      nr_reminded: :next_response_reminded,
      isescalated: :is_escalated,
      int_tc02: :resolution_escalation_level
    })
  end

  def model_changes_for_central
    changes = transformed_model_changes.with_indifferent_access
    # SchemaLessTicket has columns like text_tc01 that need to be renamed
    column_attribute_mapping.each_pair do |key, val| 
      changes[val] = changes.delete(key) if changes.key?(key)
    end
    changes[:status] = [old_status_hash(changes[:status][0]), status_hash] if status_modified?
    if association_type_modified?
      changes[:associates] = [old_association_hash, association_hash]
      changes.delete(:association_type)
    end
    changes[:description] = [nil, DONT_CARE_VALUE] if description_content_changed?
    # Handling changes to custom_fields - flexifield name should be replaced with flexifield alias
    flexifield_changes = changes.select { |k, v| k.to_s.starts_with?(*FLEXIFIELD_PREFIXES) }
    return changes if flexifield_changes.blank?

    flexifield_changes.each_pair do |key, val|
      changes[custom_field_name_mapping[key.to_s]] = convert_value(key, val)
    end
    changes.except(*flexifield_changes.keys)
  end

  def convert_value(key, val)
    return convert_file_field_values(val) if file_ticket_fields.include?(key.to_s)

    # Handling seucre field payload
    return [DONT_CARE_VALUE, DONT_CARE_VALUE] if key.to_s.starts_with?(SECURE_FIELD_PREFIX)

    val
  end

  def convert_file_field_values(values)
    values.map! { |x| x.to_i if x.present? }
  end

  def status_modified?
    @model_changes.present? && @model_changes[:status].present?
  end

  def association_type_modified?
    @model_changes.present? && @model_changes[:association_type].present?
  end

  def old_status_hash(old_status_val)
    ticket_status = Account.current.ticket_status_values_from_cache.find { |status| status.status_id == old_status_val }
    return {} if ticket_status.blank?

    { id: ticket_status.status_id, name: ticket_status.name }
  end

  def old_association_hash
    render_assoc_hash(@model_changes[:association_type][0])
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
    changes = (self.misc_changes || {}).except(*TAG_KEYS, *WATCHER_KEYS, :misc_changes)
    changes.merge!(notify_agents: agents_to_notify_sla) if sla_notification_params.present?
    changes
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
    lifecycle_hash = event_name == :create && resolved_at ? default_lifecycle_properties : @ticket_lifecycle || {}
    activity_hash = construct_activity_hash
    {
      action_in_bhrs: action_in_bhrs?,
      pod: ChannelFrameworkConfig['pod'],
      hypertrail_version: CentralConstants::HYPERTRAIL_VERSION,
      marketplace_event: valid_marketplace_event?(event_name)
    }.merge(lifecycle_hash).merge(activity_hash)
  end

  def construct_activity_hash
    if activity_type
      case activity_type[:type]
      when SPLIT_TICKET_ACTIVITY
        split_ticket_hash(activity_type)
      when MERGE_TICKET_ACTIVITY
        merge_ticket_hash(activity_type)
      when Social::Constants::TWITTER_FEED_TICKET
        social_tab_ticket_hash(activity_type)
      when ROUND_ROBIN_ACTIVITY
        round_robin_hash(activity_type)
      else
        {}
      end
    else
      {}
    end
  end

  def split_ticket_hash(activity_type)
    {
      activity_type: {
        type: SPLIT_TICKET_ACTIVITY,
        source_ticket_id: activity_type[:source_ticket_id],
        source_note_id: activity_type[:source_note_id]
      }
    }
  end

  def merge_ticket_hash(activity_type)
    {
      activity_type: {
        type: MERGE_TICKET_ACTIVITY,
        source_ticket_id: activity_type[:source_ticket_id],
        target_ticket_id: activity_type[:target_ticket_id]
      }
    }
  end

  def social_tab_ticket_hash(activity_type)
    {
      activity_type: {
        type: Social::Constants::TWITTER_FEED_TICKET
      }
    }
  end

  def round_robin_hash(activity_type)
    {
      activity_type: activity_type
    }
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

  def sla_notification_params
    ((@model_changes || {}).keys & SLA_FIELDS).select { |key| @model_changes[key][1] }
  end

  def agents_to_notify_sla
    agents = {}
    sla_notification_params.each do |field|
      escalation_key = SLA_ESCALATION_ATTRIBUTES.key(field)
      reminder_key = SLA_REMINDER_ATTRIBUTES.key(field)
      if escalation_key && sla_policy.escalation_enabled?(self)
        level = escalation_key == :resolution ? escalation_level.to_s : '1'
        agents[escalation_key] = sanitize_agent_ids(sla_policy.escalations[escalation_key.to_s].try(:[], level.to_s).try(:[], :agents_id) || [])
      elsif reminder_key
        reminder_key = "reminder_#{reminder_key}".to_sym
        agents[reminder_key] = sanitize_agent_ids(sla_policy.escalations[reminder_key.to_s].try(:[], '1').try(:[], :agents_id) || [])
      end
    end
    agents
  end

  def sanitize_agent_ids(agent_ids)
    assigned_agent_id = Helpdesk::SlaPolicy.custom_users_id_by_type[:assigned_agent]
    if agent_ids.include?(assigned_agent_id)
      agent_ids.delete(assigned_agent_id)
      agent_ids << responder_id if responder_id
      agent_ids << internal_agent_id if internal_agent_id && Account.current.shared_ownership_enabled?
    end
    agent_ids.uniq
  end
end
