class TicketFieldDecorator < ApiDecorator
  # Whenever we change the Structure (add/modify/remove keys),
  # we will have to modify the CURRENT_VERSION constant in the controller

  include Helpdesk::Ticketfields::TicketStatus

  delegate :id, :default, :description, :label, :position, :required_for_closure, :has_section?,
           :field_type, :required, :required_in_portal, :label_in_portal, :editable_in_portal, :visible_in_portal,
           :level, :ticket_field_id, :picklist_values, :i18n_label, to: :record

  # Not including default_agent and default_group because its choices are not needed for private API
  DEFAULT_FIELDS = %w[default_priority default_source default_status default_ticket_type default_product default_skill].freeze

  FIELD_NAME_MAPPINGS = {
    'product' => 'product_id',
    'group' => 'group_id',
    'agent' => 'responder_id',
    'ticket_type' => 'type',
    'requester' => 'email'
  }.freeze

  def portal_cc
    record.field_options.try(:[], 'portalcc')
  end

  def portalcc_to
    record.field_options.try(:[], 'portalcc_to')
  end

  def belongs_to_section?
    record.field_options.try(:[], 'section').present?
  end

  def default_requester?
    @field_type ||= field_type == 'default_requester'
  end

  def name
    default ? record.name : TicketDecorator.display_name(record.name)
  end

  # use the below function in case the client does not do the field name mapping
  def validatable_field_name
    default ? (FIELD_NAME_MAPPINGS[record.name] || record.name) : TicketDecorator.display_name(record.name)
  end

  def nested_ticket_field_name
    TicketDecorator.display_name(record.name)
  end

  def nested_ticket_fields
    @nested_ticket_fields ||= record.nested_ticket_fields.map { |x| TicketFieldDecorator.new(x) }
  end

  def ticket_field_choices
    @choices ||= case record.field_type
                 when 'custom_dropdown'
                   record.picklist_values.map(&:value)
                 when 'default_priority'
                   Hash[TicketConstants.priority_names]
                 when 'default_source'
                   Hash[TicketConstants.source_names]
                 when 'nested_field'
                   record.formatted_nested_choices
                 when 'default_status'
                   api_statuses = Helpdesk::TicketStatus.status_objects_from_cache(Account.current).map do |status|
                     [
                       status.status_id, [Helpdesk::TicketStatus.translate_status_name(status, 'name'),
                                          Helpdesk::TicketStatus.translate_status_name(status, 'customer_display_name')]
                     ]
                   end
                   Hash[api_statuses]
                 when 'default_ticket_type'
                   Account.current.ticket_types_from_cache.map(&:value)
                 when 'default_agent'
                   Hash[Account.current.agents_details_from_cache.map { |c| [c.name, c.id] }]
                 when 'default_group'
                   Hash[Account.current.groups_from_cache.map { |c| [CGI.escapeHTML(c.name), c.id] }]
                 when 'default_product'
                   Hash[Account.current.products_from_cache.map { |e| [CGI.escapeHTML(e.name), e.id] }]
                 else
                   []
                 end
  end

  def ticket_field_choices_by_id
    # Many of these are fetched from cache, which will not work properly in production
    # TODO-EMBER Fix caching issue
    @choices_by_id ||= case record.field_type
                       when 'custom_dropdown'
                         choices_by_id(picklist_values)
                       when 'nested_field'
                         nested_field_choices_by_id(picklist_values)
                       when *DEFAULT_FIELDS
                         safe_send(:"#{record.field_type}_choices")
                       else
                         []
                       end
  end

  def default_agent_choices
    choices_by_name_id Account.current.agents_details_from_cache
  end

  def default_group_choices
    choices_by_name_id Account.current.groups_from_cache
  end

  def to_widget_hash
    response_hash = {
      id: id,
      name: validatable_field_name,
      label: translated_label,
      description: description,
      position: position,
      required_for_closure: required_for_closure,
      required_for_agents: required,
      type: field_type,
      default: default,
      customers_can_edit: editable_in_portal,
      label_for_customers: translated_label_in_portal,
      required_for_customers: required_in_portal,
      displayed_to_customers: visible_in_portal,
      belongs_to_section: belongs_to_section?,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc)
    }
    response_hash[:choices] = default_agent_choices if field_type == 'default_agent' and default_agent_choices.present?
    response_hash[:choices] = default_group_choices if field_type == 'default_group' and default_group_choices.present?
    response_hash[:choices] = widget_default_status_choices if field_type == 'default_status' and widget_default_status_choices.present?
    response_hash[:choices] = ticket_field_choices_by_id if field_type != 'default_status' && ticket_field_choices_by_id.present?
    response_hash[:nested_ticket_fields] = nested_fields_hash if field_type == 'nested_field'
    response_hash[:portal_cc] = portal_cc if default_requester?
    response_hash[:portal_cc_to] = portalcc_to if default_requester?
    response_hash
  end

  def to_private_hash
    response_hash = {
      name: name,
      position: position,
      required_for_closure: required_for_closure,
      required_for_agents: required,
      type: field_type,
      default: default,
      customers_can_edit: editable_in_portal,
      label_for_customers: translated_label_in_portal,
      required_for_customers: required_in_portal,
      displayed_to_customers: visible_in_portal,
      belongs_to_section: belongs_to_section?
    }.merge(default_info)
    response_hash[:choices] = ticket_field_choices_by_id if ticket_field_choices_by_id.present?
    if default_requester?
      response_hash[:portal_cc] = portal_cc
      response_hash[:portal_cc_to] = portalcc_to
    end
    response_hash[:nested_ticket_fields] = nested_fields_hash if field_type == 'nested_field'
    response_hash[:sections] = sections_hash if has_section?
    response_hash
  end

  def nested_fields_hash
    nested_ticket_fields.map do |tf_nested_field|
      {
        name: tf_nested_field.nested_ticket_field_name,
        label_in_portal: tf_nested_field.translated_label_in_portal,
        level: tf_nested_field.level,
        ticket_field_id: tf_nested_field.ticket_field_id
      }.merge(tf_nested_field.default_info)
    end
  end

  def sections_hash
    picklist_values.map(&:section).compact.uniq.map do |section|
      {
        id: section.id,
        label: section.label,
        section_fields: section_field_hash(section),
        picklist_mapping_ids: section.section_picklist_mappings.map(&:picklist_value_id)
      }
    end
  end

  def default_info
    {
      id: record.id,
      label: translated_label,
      description: record.description,
      created_at: record.created_at.try(:utc),
      updated_at: record.updated_at.try(:utc)
    }
  end

  def translated_label_in_portal
    choice = level.to_i > 1 ? "customer_label_#{level}" : 'customer_label'
    label = translation_record.translations[choice] if translation_record.present?
    label || label_in_portal
  end

  private

    def nested_field_choices_by_id(pvs)
      pvs.collect do |c|
        {
          label: translated_choice(c),
          value: c.value,
          choices: nested_field_choices_by_id(c.sub_picklist_values)
        }.merge(picklist_ids(c))
      end
    end

    def choices_by_id(picklist_values)
      picklist_values.collect do |value|
        {
          label: translated_choice(value),
          value: value.value,
          id: value.id # Needed as it is used in section data.
        }.merge(picklist_ids(value))
      end
    end

    def picklist_ids(value)
      picklist_id = value.respond_to?(:picklist_id) ? value.picklist_id : nil
      picklist_id ? { choice_id: picklist_id } : {}
    end

    def choices_by_name_id(list)
      list.map do |item|
        {
          label: item.name,
          value: item.id
        }
      end
    end

    def default_priority_choices
      TicketConstants.priority_list.map do |k, v|
        {
          label: v,
          value: k
        }
      end
    end

    def default_source_choices
      if Account.current.ticket_source_revamp_enabled?
        Account.current.ticket_source_from_cache.collect do |source|
          source.new_translated_response_hash(translation_record)
        end
      else
        TicketConstants.source_names.map { |k, v| { label: k, value: v } }
      end
    end

    def default_status_choices
      # TODO-EMBER This is a cached method. Not expected work properly in production
      Helpdesk::TicketStatus.statuses_list(Account.current).map do |status|
        status_label = default_status?(status[:status_id]) ? DEFAULT_STATUSES[status[:status_id]] : translated_status(status[:status_id], status[:name])
        status.slice(:stop_sla_timer, :deleted, :group_ids).merge(
          label: status_label,
          value: status[:status_id],
          default: default_status?(status[:status_id]),
          choice_id: status[:status_id],
          customer_display_name: status_label
        )
      end
    end

    # label as customer display name - hence seperate for widget
    def widget_default_status_choices
      Helpdesk::TicketStatus.statuses_list(Account.current).map do |status|
        status_label = default_status?(status[:status_id]) ? status[:customer_display_name] : translated_status(status[:status_id], status[:customer_display_name])
        status.slice(:stop_sla_timer, :deleted, :group_ids).merge(
          label: status_label,
          value: status[:status_id],
          default: default_status?(status[:status_id]),
          choice_id: status[:status_id]
        )
      end
    end

    def default_status?(status_id)
      DEFAULT_STATUSES.keys.include?(status_id)
    end

    def default_product_choices
      choices_by_name_id Account.current.products_from_cache
    end

    def default_ticket_type_choices
      Account.current.ticket_types_from_cache.map do |type|
        {
          label: translated_choice(type),
          value: type.value,
          id: type.id # Needed as it is used in section data.
        }.merge(picklist_ids(type))
      end
    end

    def default_skill_choices
      Account.current.skills_trimmed_version_from_cache.map do |skill|
        {
          id: skill.id,
          label: skill.name,
          value: skill.id
        }
      end
    end

    def translated_label
      choice = level.to_i > 1 ? "label_#{level}" : 'label'
      label = translation_record.translations[choice] if translation_record.present?
      CGI.unescapeHTML(label || i18n_label)
    end

    def current_supported_language
      User.current.try(:supported_language) || Language.current.try(:to_key)
    end

    def current_user
      @current_user ||= User.current
    end

    def translation_record
      @translation_record ||= if Account.current.custom_translations_enabled? && current_supported_language && !TicketFieldConcern::NON_DB_FIELDS_IDS.include?(id)
                                case level
                                when 2..3
                                  record.ticket_field.safe_send("#{current_supported_language}_translation")
                                else
                                  record.safe_send("#{current_supported_language}_translation")
                                end
                              end
    end

    def translated_choice(picklist_value)
      choices = translation_record.present? && translation_record.translations['choices']
      choice = choices["choice_#{picklist_value.picklist_id}"] if choices
      CGI.unescapeHTML(choice || picklist_value.value)
    end

    def translated_status(status_id, value)
      choices = translation_record.present? && translation_record.translations['choices']
      choice = choices["choice_#{status_id}"] if choices
      CGI.unescapeHTML(choice || value)
    end

    def section_field_hash(section)
      section_fields = Account.current.archive_ticket_fields_enabled? ? Account.current.section_fields_without_archived_fields.where(section_id: section.id) : section.section_fields
      section_fields.map do |sf|
        {
          id: sf.id,
          position: sf.position,
          ticket_field_id: sf.ticket_field_id
        }
      end
    end
end
