class Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :seo_data,
           :parent, :parent_id, :draft, :attachments, :modified_at, :modified_by, to: :record

  def initialize(record, options)
    super(record)
    @user = options[:user]
  end

  def tags
    record.tags.map(&:name)
  end

  def un_html(html_string)
  	Helpdesk::HTMLSanitizer.plain(html_string)
  end

  def to_search_hash
  	ret_hash = {
		id: parent_id,
		title: title,
		description: description,
		status: status,
		agent_id: user_id,
		type: parent.art_type,
		category_id: parent.solution_category_meta.id,
		folder_id: parent.solution_folder_meta.id,
  		path: record.to_param,
		created_at: created_at,
		updated_at: updated_at,
		modified_at: modified_at,
		modified_by: modified_by
	}
	ret_hash.merge(visibility_hash)
  end

  def visibility_hash
  	return {} unless @user.present?
  	{
  		visibility: { @user.id => parent.visible?(@user) || false }
  	}
  end
end
