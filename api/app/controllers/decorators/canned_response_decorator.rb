class CannedResponseDecorator < ApiDecorator
  delegate :id, :title, :content, :content_html, :folder_id, to: :record

  def initialize(record, options)
    super(record)
    @sideload_options = options[:sideload_options]
  end

  def to_hash
    {
      id: id,
      title: title,
      content: content,
      content_html: content_html,
      folder_id: folder_id
    }
  end

  def evaluated_response
    if @sideload_options.include?('evaluated_response')
      {
        evaluated_response: Liquid::Template.parse(content_html).render(ticket: nil)
      }
    end
  end
end
