class CannedResponseDecorator < ApiDecorator
  delegate :id, :title, :content, :content_html, :folder_id, :attachments_sharable, to: :record

  def initialize(record, options)
    super(record)
    @sideload_options = options[:sideload_options]
    @ticket = options[:ticket]
  end

  def to_hash
    {
      id: id,
      title: title,
      content: content,
      content_html: content_html,
      folder_id: folder_id,
      attachments: attachments_hash
    }
  end

  def evaluated_response
    if @sideload_options.include?('evaluated_response')
      {
        evaluated_response: parse_response
      }
    end
  end

  def attachments_hash
    attachments.map { |a| AttachmentDecorator.new(a, shared_attachable_id: id).to_hash }
  end

  private

    def parse_response
      # Parses the content even when @ticket is nil
      Liquid::Template.parse(content_html).render({ ticket: @ticket, helpdesk_name: @ticket.try(:account).try(:portal_name) }.stringify_keys)
    end

    def attachments
      (@ticket && @ticket.ecommerce?) ? [] : attachments_sharable
    end
end
