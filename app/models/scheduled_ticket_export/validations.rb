class ScheduledTicketExport < ScheduledExport

  validates_presence_of :frequency, :delivery_type
  validate :filter_data_presence
  validate :fields_data_presence
  validate :email_recipients_presence, if: :send_email?
  validate :no_of_scheduled_exports_per_account, :on => :create
  validate :no_of_email_recipients_per_scheduled_export, if: :send_email?
  validate :max_fields

  protected
    def filter_data_presence
      errors.add(:base, :filter_data_presence) if filter_data.blank?
    end

    def email_recipients_presence
      errors.add(:base, :email_recipients_presence) if email_recipients.blank?
    end

    def fields_data_presence
      errors.add(:base, :fields_data_presence) if fields_data.blank?
    end

    def no_of_scheduled_exports_per_account
      if account.scheduled_ticket_exports_from_cache.count >= MAX_NO_OF_SCHEDULED_EXPORTS_PER_ACCOUNT
        errors.add(:base, :max_scheduled_exports_per_account,
                          :max_limit => MAX_NO_OF_SCHEDULED_EXPORTS_PER_ACCOUNT)
      end
    end

    def no_of_email_recipients_per_scheduled_export
      if email_recipients.count > MAX_NO_OF_EMAIL_RECIPIENTS_PER_SCHEDULED_EXPORT
        errors.add(:base, :max_no_of_email_recipients_per_scheduled_export,
                          :max_limit => MAX_NO_OF_EMAIL_RECIPIENTS_PER_SCHEDULED_EXPORT)
      end
    end

    def max_fields
      errors.add(:base, :ticket_fields_exceeds, max_limit: MAX_FIELDS) if self.ticket_fields.count > MAX_FIELDS
      errors.add(:base, :contact_fields_exceeds, max_limit: MAX_FIELDS) if self.user_fields.count > MAX_FIELDS
      errors.add(:base, :company_fields_exceeds, max_limit: MAX_FIELDS) if self.company_fields.count > MAX_FIELDS
    end  
end
