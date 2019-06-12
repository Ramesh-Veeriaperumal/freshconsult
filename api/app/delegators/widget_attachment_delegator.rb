class WidgetAttachmentDelegator < BaseDelegator

  def initialize(record, options = {})
    @widget_id = options[:widget_id]
    @widget_client_id = options[:widget_client_id]
    super(record, options)
  end

  def retrieve_draft_attachments
    attachments = Account.current.attachments.where(id: @attachment_ids, attachable_id: @widget_id, attachable_type: AttachmentConstants::WIDGET_ATTACHMENT_TYPE)
    @draft_attachments = attachments.select { |a| a.description == @widget_client_id }
  end
end
