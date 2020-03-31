class TicketSummaryDelegator < BaseDelegator
  validate :validate_application_id, if: -> { cloud_files.present? }
  validate :validate_ticket_summary
  validate :validate_agent_id
  validate :validate_last_modified_user_id, if: -> {last_modified_user_id.present?}
  validate :validate_inline_attachment_ids, if: -> { @inline_attachment_ids }
  def initialize(record, options = {})
    options[:attachment_ids] = skip_existing_attachments(options) if options[:attachment_ids]
    super(record, options)
    @inline_attachment_ids = options[:inline_attachment_ids]
    @summary = record
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
    errors[:source] << :"is invalid" unless source == Account.current.helpdesk_sources.note_source_keys_by_token["summary"]
  end

  def validate_agent_id
    agent = Account.current.technicians.where(id: user_id)
    errors[:agent_id] << :"is invalid" unless agent.present?
  end

  def validate_last_modified_user_id
    agent =  Account.current.technicians.where(id: last_modified_user_id)
    errors[:last_edited_user_id] << :"is invalid" unless agent.present?
  end

  def validate_inline_attachment_ids
    valid_ids = Account.current.attachments.where(id: @inline_attachment_ids, attachable_type: 'Tickets Image Upload').pluck(:id)
    valid_ids = valid_ids + @summary.inline_attachment_ids unless @summary.new_record? # Skip existing inline attachments while validating
    invalid_ids = @inline_attachment_ids - valid_ids
    if invalid_ids.present?
      errors[:inline_attachment_ids] << :invalid_inline_attachments_list
      (self.error_options ||= {}).merge!({ inline_attachment_ids: { invalid_ids: "#{invalid_ids.join(', ')}" } })
    end
  end

  private

    # skip parent and shared attachments
    def skip_existing_attachments(options)
      options[:attachment_ids] - (options[:parent_attachments]||[]).map(&:id) - (options[:shared_attachments]||[]).map(&:id)
    end
end
