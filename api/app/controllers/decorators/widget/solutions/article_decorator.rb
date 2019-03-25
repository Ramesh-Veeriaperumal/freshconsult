class Widget::Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :language_id,
           :parent, :parent_id, :attachments, :modified_at, :modified_by, :id, to: :record

  def initialize(record, options)
    @search_context = options[:search_context] if options.present?
    super(record)
  end

  def to_search_hash
    {
      id: parent_id,
      title: title,
      modified_at: modified_at.try(:utc),
      language_id: language_id
    }
  end

  def to_hash
    to_search_hash.merge(
      attachments: attachments_hash,
      description: description
    )
  end

  private

    def attachments_hash
      attachments.map { |a| AttachmentDecorator.new(a).to_hash }
    end
end
