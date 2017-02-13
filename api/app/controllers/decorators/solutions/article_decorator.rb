class Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :seo_data,
           :parent, :parent_id, :draft, :attachments, to: :record

  def tags
    record.tags.map(&:name)
  end

  def un_html(html_string)
  	Helpdesk::HTMLSanitizer.plain(html_string)
  end

  def to_hash
  	{
			id: parent_id,
			title: title,
			description: description,
			description_text: desc_un_html,
			status: status,
			agent_id: user_id,
			type: parent.art_type,
			category_id: parent.solution_category_meta.id,
			folder_id: parent.solution_folder_meta.id,
			thumbs_up: parent.thumbs_up,
			thumbs_down: parent.thumbs_down,
			hits: parent.hits,
			tags: tags,
			seo_data: seo_data,
			created_at: created_at,
			updated_at: updated_at
		}
  end

  alias_method :to_search_hash, :to_hash
end
