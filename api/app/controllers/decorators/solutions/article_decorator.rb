class Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :seo_data, :language_id,
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
      description_text: desc_un_html,
      status: status,
      agent_id: user_id,
      type: parent.art_type,
      category_id: parent.solution_category_meta.id,
      category_name: category_name,
      folder_id: parent.solution_folder_meta.id,
      folder_name: folder_name,
      path: record.to_param,
      created_at: created_at,
      updated_at: updated_at,
      modified_at: modified_at,
      modified_by: modified_by,
      attachments: attachments_hash
    }
    ret_hash.merge(visibility_hash)
  end

  def visibility_hash
  	return {} unless @user.present?
  	{
  		visibility: { @user.id => parent.visible?(@user) || false }
  	}
  end

  private

  	def folder_name
  		record.solution_folder_meta.send("#{language_short_code}_folder").name
  	end

  	def category_name
  		record.solution_folder_meta.solution_category_meta.send("#{language_short_code}_category").name
  	end

  	def language_short_code
  		Language.find(language_id).to_key
  	end

    def attachments_hash
      attachments.map { |a| AttachmentDecorator.new(a).to_hash }
    end

end
