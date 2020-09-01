class Helpdesk::Ticket < ActiveRecord::Base
  include RepresentationHelper
  include TicketsNotesHelper
  include TicketPresenter::PresenterHelper

  SECURE_FIELD_PREFIX = Admin::TicketFieldConstants::ENCRYPTED_FIELDS_PREFIX_BY_TYPE[:secure_text].freeze
  FLEXIFIELD_PREFIXES = (['ffs_', 'ff_text', 'ff_int', 'ff_date', 'ff_boolean', 'ff_decimal', 'dn_slt_', 'dn_mlt_'] | [SECURE_FIELD_PREFIX]).freeze
  TAG_KEYS = [:add_tag, :remove_tag].freeze
  WATCHER_KEYS = [:add_watcher, :remove_watcher].freeze
  SYSTEM_ACTIONS = [:add_comment, :add_a_cc, :email_to_requester, :email_to_group, :email_to_agent, :add_note, :forward_ticket].freeze
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

  def custom_ticket_fields
    @custom_tkt_fields ||= account.ticket_fields_from_cache.reject(&:default)
  end

  def file_ticket_fields
    custom_ticket_fields.select { |x| x.field_type == 'custom_file' }.map(&:column_name)
  end

  # *****************************************************************
  # METHODS USED BY CENTRAL PUBLISHER GEM. NOT A PART OF PRESENTER
  # *****************************************************************

  def column_attribute_mapping
    Helpdesk::SchemaLessTicket::COLUMN_TO_ATTRIBUTE_MAPPING.merge({
      sl_skill_id: :skill_id,
      owner_id: :company_id,
      boolean_tc04: :response_reminded,
      boolean_tc05: :resolution_reminded,
      nr_reminded: :next_response_reminded,
      isescalated: :is_escalated,
      int_tc02: :resolution_escalation_level,
      long_tc02: :parent_id
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
    [*ticket_body.previous_changes.keys, *(@model_changes || {}).keys.map(&:to_s)].include?('description')
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
      app_update: valid_app_event?(event_name)
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
