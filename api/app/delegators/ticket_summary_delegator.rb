class TicketSummaryDelegator < BaseDelegator
  validate :validate_application_id, if: -> { cloud_files.present? }
  validate :validate_ticket_summary
  validate :validate_agent_id
  validate :validate_last_modified_user_id, if: -> {last_modified_user_id.present?}
  def initialize(record, options = {})
    options[:attachment_ids] = skip_existing_attachments(options) if options[:attachment_ids]
    super(record, options)
  end

 def validate_application_id
    application_ids = cloud_files.map(&:application_id)
    applications = Integrations::Application.where('id IN (?)', application_ids)
    invalid_ids = application_ids - applications.map(&:id)
    if invalid_ids.any?
      errors[:application_id] << :invalid_list
      (self.error_options ||= {}).merge!(application_id: { list: invalid_ids.join(', ').to_s })
    end
  end

  def validate_ticket_summary
    errors[:source] << :"is invalid" unless source == Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["summary"]
  end

  def validate_agent_id
    agent = Account.current.technicians.where(id: user_id)
    errors[:agent_id] << :"is invalid" unless agent.present?
  end

  def validate_last_modified_user_id
    agent =  Account.current.technicians.where(id: last_modified_user_id)
    errors[:last_edited_user_id] << :"is invalid" unless agent.present?
  end

  private

    # skip parent and shared attachments
    def skip_existing_attachments(options)
      options[:attachment_ids] - (options[:parent_attachments]||[]).map(&:id) - (options[:shared_attachments]||[]).map(&:id)
    end
end
