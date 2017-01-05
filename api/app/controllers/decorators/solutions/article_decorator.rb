class Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :seo_data,
           :parent, :parent_id, :draft, :attachments, to: :record

  def tags
    record.tags.map(&:name)
  end

  def un_html(html_string)
  	Helpdesk::HTMLSanitizer.plain(html_string)
  end
end
