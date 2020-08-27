class CannedResponseDecorator < ApiDecorator
  delegate :id, :title, :content, :content_html, :folder_id, :attachments_sharable, to: :record

  def initialize(record, options)
    super(record)
    @sideload_options = options[:sideload_options]
    @ticket = options[:ticket]
  end

  def to_full_hash
    to_hash.merge(content: content,
                  content_html: content_html,
                  attachments: attachments_hash,
                  created_at: created_at.try(:utc),
                  updated_at: updated_at.try(:utc))
  end

  def to_hash
    {
      id: id,
      title: title,
      folder_id: folder_id
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
    attachments.map { |a| AttachmentDecorator.new(a).to_hash }
  end

  private

    def parse_response
      # Parses the content even when @ticket is nil
      @ticket.escape_liquid_attributes = true if @ticket
      Liquid::Template.parse(content_html).render({ ticket: @ticket.to_liquid, helpdesk_name: @ticket.try(:account).try(:helpdesk_name) }.stringify_keys)
    end

    def attachments
      (@ticket && @ticket.ecommerce?) ? [] : attachments_sharable
    end
end
