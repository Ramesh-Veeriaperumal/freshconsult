class TicketSummaryDecorator < ApiDecorator
  attr_accessor :ticket

  delegate :body, :body_html, :id, :user_id, :attachments, :attachments_sharable,
           :schema_less_note, :cloud_files, :last_modified_timestamp,
           :last_modified_user_id, to: :record

  def initialize(record, options)
    super(record)
    @ticket = options[:ticket]
    @sideload_options = options[:sideload_options] || []
  end

  def construct_json
    {
      body: body_html,
      body_text: body,
      id: id,
      user_id: user_id,
      ticket_id: @ticket.display_id,
      created_at: created_at.try(:utc),
      updated_at: updated_at.try(:utc),
      attachments: attachments.map { |att| AttachmentDecorator.new(att).to_hash }
    }
  end

  def to_json
    construct_json.merge(
      last_edited_at: last_modified_timestamp.try(:utc),
      last_edited_user_id: last_modified_user_id.try(:to_i),
      attachments: attachments_hash,
      cloud_files: cloud_files_hash,
    )
  end

  def to_hash
    to_json.merge(requester_hash)
  end

  def attachments_hash
    (attachments | attachments_sharable).map { |a| AttachmentDecorator.new(a).to_hash }
  end

  def cloud_files_hash
    cloud_files.map { |cf| CloudFileDecorator.new(cf).to_hash }
  end

  def requester_hash
    return {} unless @sideload_options.include?('requester')
    contact_decorator = ContactDecorator.new(record.user, {}).to_hash
    { requester: contact_decorator }
  end

end
