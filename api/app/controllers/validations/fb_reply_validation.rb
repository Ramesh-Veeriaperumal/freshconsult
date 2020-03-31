class FbReplyValidation < ApiValidation
  include Facebook::TicketActions::Util

  attr_accessor :body, :note_id, :agent_id, :msg_type, :attachment_ids

  validates :body, data_type: { rules: String, required: true, allow_nil: false }, if: -> { !facebook_outgoing_attachment_enabled? }

  validates :note_id, :agent_id, custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param }

  validate :validate_facebook_ticket, if: -> { @ticket.present? }

  validates :body, data_type: { rules: String, allow_nil: false }, if: -> { facebook_outgoing_attachment_enabled? }
  validates :msg_type, data_type: { rules: String, required: true }, custom_inclusion: { in: Facebook::Constants::FB_MSG_TYPES }, if: -> { facebook_outgoing_attachment_enabled? }
  validates :attachment_ids, data_type: { rules: Array }, array: { data_type: { rules: Integer } }, custom_length: { maximum: 1 }, if: -> { facebook_outgoing_attachment_enabled? }
  validate :either_body_attachment_ids, if: -> { facebook_outgoing_attachment_enabled? }

  def initialize(request_params, item, allow_string_param = false)
    @ticket = item
    super(request_params, nil, allow_string_param)
  end

  def validate_facebook_ticket
    errors[:ticket_id] << :not_a_facebook_ticket unless @ticket.source ==  Account.current.helpdesk_sources.ticket_source_keys_by_token[:facebook]
  end

  def either_body_attachment_ids
    if body.present? && attachment_ids.present? && msg_type == Facebook::Constants::FB_MSG_TYPES[0]
      errors[:attachment_ids] << :can_have_only_one_field
      (self.error_options ||= {})[:attachment_ids] = { list: 'body, attachment_ids' }
    end
    errors[:body] << :missing_field if body.blank? && attachment_ids.blank?
  end
end
