class Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :seo_data, :parent, :parent_id, to: :record

  def tags
    record.tags.map(&:name)
  end
end
