class Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :seo_data, :language_id,
           :parent, :parent_id, :draft, :attachments, :modified_at, :modified_by, :id, to: :record

  SEARCH_CONTEXTS_WITHOUT_DESCRIPTION = [:agent_insert_solution]

  def initialize(record, options)
    super(record)
    @user = options[:user]
    @search_context = options[:search_context]
  end

  def tags
    record.tags.map(&:name)
  end

  def un_html(html_string)
    Helpdesk::HTMLSanitizer.plain(html_string)
  end

  def article_info
    ret_hash = {
      id: parent_id,
      type: parent.art_type,
      category_id: parent.solution_category_meta.id,
      folder_id: parent.solution_folder_meta.id,
      agent_id: user_id,
      path: record.to_param,
      modified_at: modified_at.try(:utc),
      modified_by: modified_by
    }
    ret_hash.merge!(draft_info(draft || record))
    ret_hash.merge!(visibility_hash)
  end

  def to_search_hash
    article_info.merge(
      category_name: category_name,
      folder_name: folder_name
    )
  end

  def to_hash
    article_info.merge(
      attachments: attachments_hash,
      thumbs_up: parent.thumbs_up,
      thumbs_down: parent.thumbs_down,
      hits: parent.hits,
      seo_data: seo_data
    )
  end

  def draft_info(item)
    ret_hash = {
          title: item.title,
          status: item.status,
          created_at: item.created_at.try(:utc),
          updated_at: item.updated_at.try(:utc)
        }
    ret_hash.merge!(description_hash(item)) unless @search_context && SEARCH_CONTEXTS_WITHOUT_DESCRIPTION.include?(@search_context)
    ret_hash
  end

  def visibility_hash
    return {} unless @user.present?
    {
      visibility: { @user.id => parent.visible?(@user) || false }
    }
  end

  def content_hash
    ret_hash = {
        id: parent_id,
        attachments: attachments_hash
      }
    ret_hash.merge!(description_hash(draft || record))
  end

  private

    def folder_name
      record.solution_folder_meta.safe_send("#{language_short_code}_folder").name
    end

    def category_name
      record.solution_folder_meta.solution_category_meta.safe_send("#{language_short_code}_category").name
    end

    def language_short_code
      Language.find(language_id).to_key
    end

    def attachments_hash
     attachments.map { |a| AttachmentDecorator.new(a).to_hash }
    end

    def description_hash(item)
      {
        description: item.description,
        description_text: item.is_a?(Solution::Article) ? desc_un_html : un_html(item.description),
      }
    end
end
