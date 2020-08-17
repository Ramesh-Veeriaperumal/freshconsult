module Admin::Automation::AutomationSummary
  include Admin::AutomationConstants
  include Admin::Automation::CustomStatusHelper
  attr_accessor :record

  def generate_summary(record, add_html_tag = false)
    @current_account ||= Account.current
    @record = record
    @custom_checkbox = []
    @add_html_tag = add_html_tag
    custom_ticket_fields
    AUTOMATION_FIELDS[VAConfig::RULES_BY_ID[record.rule_type]].inject({}) do |hash, key|
      hash.merge!(key.to_sym => safe_send(:"#{key}_summary"))
    end
  rescue Exception => e
    NewRelic::Agent.notice_error(e)
    {}
  end

  private

    def performer_summary
      performer_type = record.rule_performer.instance_variable_get(:@type)
      performer_type = service_task_performer_text_change performer_type if record.service_task_automation?
      requesters = record.rule_performer.instance_variable_get(:@members)
      performer = add_html_tag(I18n.t("admin.automation_summary.performer_#{performer_type}"), 1)
      if requesters.nil?
        I18n.t('admin.automation_summary.performer', field_name: performer)
      else
        p_value = generate_value(:responder_id, requesters, ' OR ')
        I18n.t('admin.automation_summary.performer_value', field_name: performer, field_value: p_value)
      end
    end

    def service_task_performer_text_change(performer_type)
      if performer_type == PERFORMER_TYPES[:agent]
        PERFORMER_TYPES[:field_technician]
      elsif performer_type == PERFORMER_TYPES[:agent_or_requester]
        PERFORMER_TYPES[:field_technician_or_requester]
      else
        performer_type
      end
    end

    def events_summary
      sentence = []
      record.rule_events.map do |event|
        event.rule.deep_symbolize_keys
        sentence << I18n.t('admin.automation_summary.condition_any') if sentence.present?
        generated_sentence = if event.rule.key?(:nested_rule)
                               event_nested_sentence_generate(event.rule)
                             else
                               event_sentence_generate(event.rule)
                             end
        sentence << generated_sentence if generated_sentence.present?
      end
      sentence
    end

    def conditions_summary
      return {} if record.rule_conditions.blank?
      conditions = record.rule_conditions
      operator = record.rule_operator
      if conditions.first && (conditions.first.key?(:all) || conditions.first.key?(:any))
        multiple_condition_summary(conditions, operator)
      else
        { 'condition_set_1'.to_sym => condition_set_summary(conditions, operator) }
      end
    end

    def multiple_condition_summary(conditions, operator)
      conditions.each_with_index.inject({}) do |hash, (condition_set, index)|
        condition_operator = operator == :any ? :condition_any : :condition_all
        hash[:operator] = I18n.t("admin.automation_summary.#{condition_operator}") if index == 1
        hash.merge!("condition_set_#{index + 1}" =>
            condition_set_summary(condition_set.values.first, condition_set.keys.first))
      end
    end

    def actions_summary
      sentence = []
      record.action_data.map do |action|
        action.deep_symbolize_keys
        sentence << I18n.t('admin.automation_summary.condition_all') if sentence.present?
        generated_sentence = if action.key?(:nested_rules)
                               nested_fields_sentence_generate(action, :action, :category_name)
                             else
                               action_sentence_generate(action)
                             end
        sentence << generated_sentence if generated_sentence.present?
      end
      sentence
    end

    def event_sentence_generate(data)
      return if data[:name].nil?

      name = data[:name].to_sym == :note_type ? :note_added : :event
      if data.key?(:value)
        name = :"#{name}_value"
        values = [data[:value]]
        values = [I18n.t("admin.automation_summary.#{data[:value]}")] if data[:name] == 'ticket_action'
      elsif data.key?(:from)
        name = :"#{name}_from_to"
        values = [data[:from], data[:to]]
      end
      create_sentence(data[:name], name, values, 'ticket', :event)
    end

    def condition_set_summary(condition_set, match_type)
      sentence = []
      operator = match_type == :any ? :condition_any : :condition_all
      condition_set.each do |condition|
        condition.deep_symbolize_keys
        sentence << I18n.t("admin.automation_summary.#{operator}") if sentence.present?
        generated_sentence = if condition.key?(:nested_rules)
                               nested_fields_sentence_generate(condition, :condition)
                             else
                               condition_sentence_generate(condition)
                             end
        sentence << generated_sentence if generated_sentence.present?
      end
      sentence
    end

    def condition_sentence_generate(data)
      return if data[:name].nil?

      is_supervisor = record.supervisor_rule?
      field_name =  is_supervisor && TIME_BASE_DUPLICATE.include?(field_name) ? :"#{field_name}_since" : data[:name].to_sym
      field_name = TIME_AND_STATUS_BASED_FILTER[0] if data[:name].to_s.include? TIME_AND_STATUS_BASED_FILTER[0]
      array = []
      array << generate_key(data[:name], data[:evaluate_on] || 'ticket')
      field = ticket_fields.find { |tf| tf.name == data[:name] }
      summary_operator = TAGS_OPERATOR_MAPPING[data[:operator].to_sym] || data[:operator] if field_name == :tag_ids
      field.present? && field.field_type == 'custom_date' && data[:operator].present? ?
          array << generate_operator(DATE_FIELDS_OPERATOR_MAPPING[data[:operator].to_sym] || data[:operator]) :
          array << generate_operator(summary_operator || data[:operator]) if data[:operator].present?
      if data.key? :value
        value = if SUBJECT_DESCRIPTION_FIELDS.include?(data[:name]) || (field.present? &&
                                                CUSTOM_TEXT_FIELD_TYPES.include?(field.field_type.to_sym))
                  data[:value].is_a?(Array) ? data[:value].map { |val| CGI.escapeHTML(val) } : CGI.escapeHTML(data[:value])
                else
                  data[:value]
                end
        array << generate_value(data[:name], value, ' OR ')
      end
      array << generate_case_sensitive(data[:case_sensitive]) if data[:case_sensitive].present?
      array << generate_associated_fields(data[:associated_fields]) if data[:associated_fields].present?
      array << fetch_related_condition_fields(data, []) if data[:related_conditions].present?
      sentence = array.join(' ')
      I18n.t('admin.automation_summary.condition', field_name: sentence)
    end

    def action_sentence_generate(data)
      field_name = data[:name].try(:to_sym)
      translated_key = :action
      return if field_name.nil?
      values = nil
      case true
      when data.key?(:value)
        translated_key = ACTION_FIELDS_SUMMARY.include?(field_name) ? :action_key_value : :action_value
        values = [data[:value]]
      when SEND_EMAIL_ACTION_FIELDS.include?(field_name)
        values = [data[:email_to]]
        translated_key = :action_key_value
      when field_name == :add_note
        values = [data[:notify_agents]]
        translated_key = :action_key_value
      when field_name == :forward_ticket
        sentence_parts = [I18n.t('admin.automation_summary.forward_ticket', fwd_to: [*data[:fwd_to]].join(', '))]
        sentence_parts << I18n.t('admin.automation_summary.with_cc', fwd_cc: [*data[:fwd_cc]].join(', ')) if data[:fwd_cc].present?
        sentence_parts << I18n.t('admin.automation_summary.with_bcc', fwd_bcc: [*data[:fwd_bcc]].join(', ')) if data[:fwd_bcc].present?
        return sentence_parts.join('; ')
      when field_name == :trigger_webhook
        name = generate_key(field_name)
        request_type = generate_value(:trigger_webhook, data[:request_type].to_sym)
        return I18n.t('admin.automation_summary.action_webhook',
                      field_name: name, field_from: request_type, field_to: data[:url])
      end
      create_sentence(field_name, translated_key, values, 'ticket', :action, data[:evaluate_on])
    end

    def nested_fields_sentence_generate(data, type, field_name = :name)
      nested_data = data[:nested_rule].presence || data[:nested_rules].presence
      translated_key = data.key?(:value) ? :"#{type}_value" : :"#{type}_from_to"
      values = data.key?(:value) ? [data[:value]] : [data[:from], data[:to]]

      key = generate_key(data[field_name], data[:evaluate_on] || 'ticket')
      operator = data[:operator].present? ? data[:operator] : 'as'
      operator = generate_operator(operator)
      value = generate_value(data[field_name], data[:value], ' OR ') unless data[:value].nil?
      sentence = I18n.t("admin.automation_summary.#{translated_key}", field_name: key, field_operator: operator, field_value: value)
      nested_data.each do |nested_value|
        nested_sentence = nested_fields_sentence_generate(nested_value, "#{type}_nested")
        sentence = "#{sentence}#{nested_sentence}"
      end
      sentence
    end

    def event_nested_sentence_generate(data)
      nested_data = data[:nested_rule].presence || data[:nested_rules].presence
      array = []
      array << event_sentence_generate(data)
      nested_data.each do |nested_value|
        array << event_sentence_generate(nested_value)
      end
      sentence = array.join(I18n.t('admin.automation_summary.and'))
      sentence
    end

    def create_sentence(field_name, cons_field_name, value = nil, evaluate_on = 'ticket', type = nil, action_resource_type = nil)
      name = generate_key(field_name, evaluate_on, ', ', type, action_resource_type)
      field = ticket_fields.find { |tf| tf.name == field_name.to_s }
      value = value.map { |val| CGI.escapeHTML(val) } if field.present? && CUSTOM_TEXT_FIELD_TYPES.include?(field.field_type.to_sym)
      value1 = generate_value(field_name, value.first || I18n.t('admin.automation_summary.none')) if value.present?
      value2 = generate_value(field_name, value.second ||
                  I18n.t('admin.automation_summary.none')) if value.present? && value.length == 2
      resource_type = resouce_type_translation action_resource_type if action_resource_type.present?
      I18n.t("admin.automation_summary.#{cons_field_name}",
             field_name: name, field_value: value1, field_from: value1, field_to: value2,
             resource_type: resource_type)
    end

    def resouce_type_translation(action_resource_type)
      if SAME_TICKET_EVALUATE_ON == action_resource_type && record.service_task_automation?
        I18n.t('admin.automation_summary.same_service_task')
      else
        I18n.t("admin.automation_summary.#{action_resource_type}")
      end
    end

    def get_name(method_name, input, separator = ', ')
      if method_name == :add_watcher || method_name == :add_note
        separator = ' AND '
        method_name = :responder_id
      end
      array = []
      hash = safe_send(:"#{method_name}")
      if input.is_a?(Array)
        input.map { |val| array << (DEFAULT_ANY_NONE.include?(val) ? DEFAULT_ANY_NONE[val] : hash[val.to_s]) }
        array.join(separator)
      else
        DEFAULT_ANY_NONE.include?(input) ? DEFAULT_ANY_NONE[input] : hash[input.to_s]
      end
    end

    def generate_key(field_name, evaluate_on = 'ticket', separator = ', ', type = nil, action_resource_type = nil)
      action_resource_type ||= evaluate_on
      value = action_summary_default_fields_text_change(type, field_name, action_resource_type)
      if value.nil?
        value = if field_name.to_s.include? TIME_AND_STATUS_BASED_FILTER[0].to_s
                  supervisor_custom_status_name(field_name)
                else
                  evaluate_on = 'ticket' unless EVALUATE_ON_MAPPING.values.include?(evaluate_on)
                  get_name("custom_#{evaluate_on}_fields", field_name, separator)
                end
        end
      add_html_tag(value, 1)
    end

    def action_summary_default_fields_text_change(type, field_name, action_resource_type)
      if type == :action && ACTION_FIELDS_SUMMARY.include?(field_name.try(:to_sym))
        field_name = service_task_condition_action_text_change(field_name, action_resource_type) if record.service_task_automation?
        I18n.t("admin.automation_summary.action_#{field_name}")
      elsif SUMMARY_DEFAULT_FIELDS.include?(field_name.try(:to_sym))
        field_name = service_task_condition_action_text_change(field_name, action_resource_type) if record.service_task_automation?
        I18n.t("admin.automation_summary.#{field_name}")
      end
    end

    def service_task_condition_action_text_change(field_name, action_resource_type)
      if service_task_resource_type?(action_resource_type)
        case field_name.to_s
          when RESPONDER_ID_FIELD_NAME
            FIELD_SERVICE_RESPONDER_ID
          when GROUP_ID_FIELD_NAME
            FIELD_SERVICE_GROUP_ID
          when ADD_NOTE_ACTION
            ADD_NOTE_AND_NOTIFY_FEIELD_TECH
          when SEND_EMAIL[:agent]
            SEND_EMAIL[:field_tech]
          when SEND_EMAIL[:group]
            SEND_EMAIL[:field_group]
          else
            field_name
        end
      else
        field_name
      end
    end

    def service_task_resource_type?(action_resource_type)
      SERVICE_TASK_RESOURCE_TYPES.include?(action_resource_type.to_s)
    end

    def generate_value(field_name, value, separator = ', ')
      if SEND_EMAIL_ACTION_FIELDS.include?(field_name)
        field_name = field_name == :send_email_to_group ? :group_id : :responder_id
      end
      value = if @custom_checkbox.include?(field_name) || field_name.to_s.include?('ff_boolean')
                I18n.t("admin.automation_summary.#{value}")
              elsif field_name.to_sym == :tag_ids
                fetch_tag_names(value)
              else
                get_value(field_name, value, separator)
              end
      add_html_tag(value, 2)
    end

    def get_value(field_name, value, separator)
      case true
      when DEFAULT_ANY_NONE.include?(value)
        DEFAULT_ANY_NONE[value]
      when FIELD_WITH_IDS.include?(field_name.to_sym)
        get_id_value(field_name, value, separator)
      when value.is_a?(Array)
        array = []
        value.each { |val| array << (DEFAULT_ANY_NONE.include?(val) ? DEFAULT_ANY_NONE[val] : val) }
        array.join(separator)
      else
        value
      end
    end

    def get_id_value(field_name, value, separator)
      if field_name == :responder_id && RESPONDER_ACTIONS_ID.include?(value)
        case value
        when 0
          record.service_task_automation? ? I18n.t('admin.automation_summary.assigned_field_service_agent') : I18n.t('admin.automation_summary.assigned_agent')
        when -2
          record.dispatchr_rule? ? I18n.t("admin.automation_summary.ticket_creating_agent") :
                                   I18n.t("admin.automation_summary.event_agent")
        end
      elsif field_name.to_sym == :customer_feedback
        active_survey? ? get_name(field_name, value, separator) : ''
      else
        get_name(field_name, value, separator)
      end
    end

    def generate_case_sensitive(value)
      value = add_html_tag(value, 2)
      text_and = I18n.t('admin.automation_summary.condition_all')
      text_match_case = I18n.t('admin.automation_summary.match_case')
      text_is = I18n.t('admin.automation_summary.is')
      "#{text_and.downcase} #{text_match_case} #{text_is} #{value}"
    end

    def generate_associated_fields(associated_fields)
      value = add_html_tag(associated_fields[:value], 2)
      text_and = I18n.t('admin.automation_summary.condition_all')
      text_related_ticket_count = add_html_tag(I18n.t('admin.automation_summary.related_ticket_count'), 1)
      operator = I18n.t("admin.automation_summary.#{associated_fields[:operator]}")
      "#{text_and.downcase} #{text_related_ticket_count} #{operator} #{value}"
    end

    def fetch_related_condition_fields(data, agent_shifts_array)
      data[:related_conditions].each do |related_condition|
        agent_shifts_array << generate_related_condition_fields(related_condition)
        fetch_related_condition_fields(related_condition, agent_shifts_array) if related_condition.key? :related_conditions
      end
      agent_shifts_array
    end

    def generate_related_condition_fields(agent_shifts)
      text_and = I18n.t('admin.automation_summary.condition_all')
      availability = I18n.t("admin.automation_summary.#{agent_shifts[:name]}")
      operator = I18n.t("admin.automation_summary.#{agent_shifts[:operator]}")
      agent_shifts_value = agent_shifts[:value] == "-1" ? I18n.t("admin.automation_summary.any_days") : agent_shifts[:value].humanize
      value = add_html_tag(agent_shifts_value, 2)
      "#{text_and} #{availability} #{operator} #{value}"
    end

    def generate_operator(t_value)
      t_value = I18n.t("admin.automation_summary.#{t_value}")
      add_html_tag(t_value, 3)
    end

    def add_html_tag(input, type)
      @add_html_tag && input.present? ? "<div class = Summary#{HASH_SUMMARY_CLASS[type]}>#{input}</div>" : input
    end

    def priority
      PRIORITY_MAP
    end

    def association_type
      TicketConstants::TICKET_ASSOCIATION_TOKEN_BY_KEY.keys.inject({}) do |hash, key|
        hash[key.to_s] = TicketConstants.translate_association_type_name(key)
        hash
      end
    end

    def trigger_webhook
      WEBHOOK_HTTP_METHODS_KEY_VALUE
    end

    def source
      SOURCE
    end

    def language
      LANGUAGE_HASH
    end

    def status
      @status ||= record.account.ticket_status_values_from_cache.inject({}) do |hash, key|
        hash.merge!(key[:status_id].to_s => key[:name])
      end
    end

    def group_id
      @group_id ||= record.account.groups_from_cache.inject({}) do |hash, key|
        hash.merge!(key[:id].to_s => key[:name])
      end.merge!('0' => I18n.t('admin.automation_summary.assigned_group'))
    end

    def responder_id
      @responder_id ||= record.account.agents_details_from_cache.inject({}) do |hash, key|
        hash.merge!(key.id.to_s => key.name)
      end.merge!('0' => I18n.t('admin.automation_summary.none_agent'), '-2' => I18n.t('admin.automation_summary.event_agent'))
    end

    def product_id
      @product_id ||= record.account.products_from_cache.inject({}) do |hash, key|
        hash.merge!(key.id.to_s => key.name)
      end
    end

    def customer_feedback
      return unless active_survey?

      @customer_feedback ||= record.account.active_custom_survey_choices.inject({}) do |hash, key|
        hash.merge!(key[:face_value].to_s => key[:value])
      end
    end

    def active_survey?
      record.account.active_custom_survey_from_cache.present?
    end

    def segments
      @segments ||= record.account.contact_filters_from_cache.inject({}) do |hash, key|
        hash.merge!(key.id.to_s => key.name)
      end
    end

    def custom_ticket_fields
      @custom_ticket_fields ||= begin
        ticket_fields = record.account.ticket_fields_from_cache.reject(&:default)
        ticket_fields.inject({}) do |hash, key|
          @custom_checkbox << key[:name].to_sym if key[:flexifield_coltype] == 'checkbox'
          hash.merge!(key[:column_name].to_s => key[:label]) && hash.merge!(key[:name].to_s => key[:label])
        end
      end
    end

    def custom_company_fields
      @custom_company_fields ||= record.account.company_form.custom_company_fields.inject({}) do |hash, key|
        hash.merge!(key[:name].to_s => key[:label])
      end
    end

    def custom_requester_fields
      @custom_requester_fields ||= record.account.contact_form.custom_contact_fields.inject({}) do |hash, key|
        hash.merge!(key[:name].to_s => key[:label])
      end
    end

    def ticket_fields
      @ticket_fields ||= Account.current.ticket_fields_from_cache
    end

    def fetch_tag_names(tag_ids)
      Account.current.tags.where(id: tag_ids).select("name").map(&:name).join(', ')
    end

    def freddy_suggestion
      { 'thank_you_note' => I18n.t('admin.automation_summary.thank_you_note') }
    end

    alias_method :internal_agent_id, :responder_id
    alias_method :internal_group_id, :group_id
end
