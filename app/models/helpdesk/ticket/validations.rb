class Helpdesk::Ticket < ActiveRecord::Base
  include TicketFilterConstants

  validates_presence_of :requester_id, :message => "should be a valid email address"
  validates_numericality_of :source, :status, :only_integer => true
  validates_numericality_of :requester_id, :responder_id, :only_integer => true, :allow_nil => true
  validate :inclusion_of_source
  validate :exclusion_of_source, on: :create, unless: :support_bot_configured?, message: I18n.t('not_supported')
  validates_inclusion_of :priority, :in => PRIORITY_TOKEN_BY_KEY.keys, :message=>"should be a valid priority" #for api
  validates_uniqueness_of :display_id, :scope => :account_id
  validate :due_by_validation, :if => :due_by
  #validate :frDueBy_validation, :if => :frDueBy
  validate :presence_of_required_fields, :if => :required_fields
  validate :presence_of_required_fields_for_closure, :if => :required_fields_on_closure

  validate on: :create do |ticket|
    req = ticket.requester
    if req
      ticket.spam = true if req.deleted?
      if req.blocked?
        Rails.logger.debug "User blocked! No more tickets allowed for this user"
        ticket.errors.add(:base, ErrorConstants::ERROR_MESSAGES[:user_blocked_error])
      end
    end
  end

  validate on: :create do |ticket|
    if (ticket.cc_email && ticket.cc_email[:cc_emails] &&
      ticket.cc_email[:cc_emails].length >= TicketConstants::MAX_EMAIL_COUNT)
      Rails.logger.debug "You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} cc emails for this ticket"
      ticket.errors.add(:base,"You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} cc emails for this ticket")
    end
  end

  validate :requester_company_id_validation, :if => :company_id_changed?

  validate :field_agent_can_manage_appointments?, on: :update, if: -> { errors.blank? && valid_service_task? }
  validate :check_appointment_time_range, if: -> { errors.blank? && valid_service_task? }

  def due_by_validation
    self.errors.add(:base,t('helpdesk.tickets.show.due_date.earlier_date_and_time')) if due_by_changed? and (due_by < created_at_date)
  end

  def frDueBy_validation
    self.errors.add(:base,t('helpdesk.tickets.show.due_date.earlier_date_and_time')) if frDueBy < created_at_date
  end

  def valid_service_task?
    Account.current.field_service_management_enabled? && service_task?
  end

  def created_at_date #To handle API call having frDueBy and due_by without created_at
    created_at || Time.zone.now
  end

  def presence_of_required_fields
    error_label = required_fields[:error_label]
    fields      = required_fields[:fields]

    fields.each do |field|
      field_value = safe_send(field.field_name)
      if field_value_blank?(field_value)
        add_required_field_error(field, error_label)
        next
      end

      if field.nested_field?
        parent_picklist = find_picklist(field.picklist_values, field_value)
        next if parent_picklist.nil?

        field.nested_ticket_fields.each do |child_field|
          child_field_value = safe_send(child_field.field_name)
          if field_value_blank?(child_field_value)
            add_required_field_error(child_field, error_label) if parent_picklist.sub_picklist_values.any?
            break
          end
          parent_picklist = find_picklist(parent_picklist.sub_picklist_values, child_field_value)
          break if parent_picklist.nil?
        end
      end
    end
  end

  def presence_of_required_fields_for_closure
    account.required_ticket_fields_from_cache.each do |field|
      return false unless field_validations(field)
    end

    account.section_parent_fields_from_cache.each do |field|
      picklist = find_picklist(field.picklist_values, safe_send(field.name))
      picklist.section.reqd_ticket_fields.each do |ticket_field|
        return false unless field_validations(ticket_field)
      end if picklist && picklist.section
    end

    true
  end

  def field_validations field
    return false unless validate_field(field, safe_send(field.name))
    return false if field.nested_field? && !validate_nested_field(field)
    true
  end

  def validate_field field, value
    if field_value_blank?(value)
      add_required_field_error field, :label
      return false
    end
    true
  end

  def validate_nested_field field
    parent_picklist = find_picklist(field.picklist_values, safe_send(field.name))

    field.nested_ticket_fields.each do |child_field|
      break if parent_picklist.nil? || parent_picklist.sub_picklist_values.empty?
      child_field_value = safe_send(child_field.field_name)
      return false unless validate_field(child_field, child_field_value)
      parent_picklist = find_picklist(parent_picklist.sub_picklist_values, child_field_value)
    end
    true
  end

  # For API
  def requester_company_id_validation
    if self.owner_id.present? && !requester.company_ids.include?(self.owner_id)
      self.errors.add(
        :company_id,
        "The requester does not belong to the specified company"
      )
    end
  end

  def check_appointment_time_range
    start_time = generate_flexifield_alias_name(FSM_APPOINTMENT_START_TIME)
    end_time = generate_flexifield_alias_name(FSM_APPOINTMENT_END_TIME)
    unless self.custom_field[start_time].nil? || self.custom_field[end_time].nil?
      if self.custom_field[end_time] < self.custom_field[start_time]
        end_time_ff = get_flexifield_mapping_entry(end_time)
        if self.flexifield.changes.key?(end_time_ff)
          self.errors.add(:"custom_fields.#{FSM_APPOINTMENT_END_TIME}", 'invalid_date_time_range')
        else
          self.errors.add(:"custom_fields.#{FSM_APPOINTMENT_START_TIME}", 'invalid_date_time_range')
        end
      end
    end
  end

  def field_agent_can_manage_appointments?
    if User.current && User.current.agent && User.current.agent.field_agent?
      unless Account.current.field_agents_can_manage_appointments?
        start_time = generate_flexifield_alias_name(FSM_APPOINTMENT_START_TIME)
        end_time = generate_flexifield_alias_name(FSM_APPOINTMENT_END_TIME)
        start_time_ff = get_flexifield_mapping_entry(start_time)
        end_time_ff = get_flexifield_mapping_entry(end_time)
        errors.add(:"custom_fields.#{FSM_APPOINTMENT_START_TIME}", 'access_denied') if flexifield.changes.key?(start_time_ff)
        errors.add(:"custom_fields.#{FSM_APPOINTMENT_END_TIME}", 'access_denied') if flexifield.changes.key?(end_time_ff)
      end
    end
  end

  def inclusion_of_source
    Account.current.helpdesk_sources.ticket_source_keys_by_token.values.include?(source)
  end

  def exclusion_of_source
    !Account.current.helpdesk_sources.ticket_source_keys_by_token[:bot].equal?(source)
  end

  private

    def add_required_field_error field, error_label
      self.errors.add(field.safe_send(error_label), I18n.t("ticket.errors.required_field"))
    end

    def field_value_blank? field_value
      field_value.blank? || field_value.is_a?(FalseClass) # latter condition for checkbox alone
    end

    def find_picklist(picklists, value)
      picklists.find do |picklist| picklist.value == value end
    end

    def support_bot_configured?
      self.account.support_bot_configured?
    end

    def generate_flexifield_alias_name(field_name)
      field_name + "_#{Account.current.id}".freeze
    end

    def get_flexifield_mapping_entry(key)
      custom_field_name_mapping.key(key)
    end
end
