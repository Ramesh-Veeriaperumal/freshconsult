class Helpdesk::Ticket < ActiveRecord::Base

	validates_presence_of :requester_id, :message => "should be a valid email address"
  validates_numericality_of :source, :status, :only_integer => true
  validates_numericality_of :requester_id, :responder_id, :only_integer => true, :allow_nil => true
  validates_inclusion_of :source, :in => 1..SOURCES.size
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
        ticket.errors.add(:base,"User blocked! No more tickets allowed for this user")
      end
    end
  end

  validate on: :create do |ticket|
    if (ticket.cc_email && ticket.cc_email[:cc_emails] &&
      ticket.cc_email[:cc_emails].count >= TicketConstants::MAX_EMAIL_COUNT)
      Rails.logger.debug "You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} cc emails for this ticket"
      ticket.errors.add(:base,"You have exceeded the limit of #{TicketConstants::MAX_EMAIL_COUNT} cc emails for this ticket")
    end
  end

  validate :requester_company_id_validation, :if => :company_id_changed?

  def due_by_validation
    self.errors.add(:base,t('helpdesk.tickets.show.due_date.earlier_date_and_time')) if due_by_changed? and (due_by < created_at_date)
  end

  def frDueBy_validation
    self.errors.add(:base,t('helpdesk.tickets.show.due_date.earlier_date_and_time')) if frDueBy < created_at_date
  end

  def created_at_date #To handle API call having frDueBy and due_by without created_at
    created_at || Time.zone.now
  end

  def presence_of_required_fields
    error_label = required_fields[:error_label]
    fields      = required_fields[:fields]

    fields.each do |field|
      field_value = send(field.field_name)
      if field_value_blank?(field_value)
        add_required_field_error(field, error_label)
        next
      end

      if field.nested_field?
        parent_picklist = find_picklist(field.picklist_values, field_value)
        next if parent_picklist.nil?

        field.nested_ticket_fields.each do |child_field|
          child_field_value = send(child_field.field_name)
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
      picklist = find_picklist(field.picklist_values, send(field.name))
      picklist.required_ticket_fields.each do |ticket_field|
        return false unless field_validations(ticket_field)
      end if picklist
    end

    true
  end

  def field_validations field
    return false unless validate_field(field, send(field.name))
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
    parent_picklist = find_picklist(field.picklist_values, send(field.name))

    field.nested_ticket_fields.each do |child_field|
      break if parent_picklist.nil? || parent_picklist.sub_picklist_values.empty?
      child_field_value = send(child_field.field_name)
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

  private

    def add_required_field_error field, error_label
      self.errors.add(field.send(error_label), I18n.t("ticket.errors.required_field"))
    end

    def field_value_blank? field_value
      field_value.blank? || field_value.is_a?(FalseClass) # latter condition for checkbox alone
    end

    def find_picklist(picklists, value)
      picklists.find do |picklist| picklist.value == value end
    end

end
