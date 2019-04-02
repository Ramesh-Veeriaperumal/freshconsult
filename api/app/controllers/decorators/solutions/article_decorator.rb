class Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :seo_data, :language_id,
           :parent, :parent_id, :draft, :attachments, :cloud_files, :article_ticket, :modified_at,
           :modified_by, :id, :to_param, :tags, :voters, :thumbs_up, :thumbs_down, to: :record

  SEARCH_CONTEXTS_WITHOUT_DESCRIPTION = [:agent_insert_solution, :filtered_solution_search].freeze

  def initialize(record, options = {})
    super(record)
    @user = options[:user]
    @search_context = options[:search_context]
    @draft = options[:draft]
  end

  def fetch_tags
    record.tags.map(&:name)
  end

  def un_html(html_string)
    Helpdesk::HTMLSanitizer.plain(html_string)
  end

  def article_info
    ret_hash = {
      id: parent_id,
      type: parent.art_type,
      category_id: category_id,
      status: status,
      folder_id: parent.solution_folder_meta.id,
      agent_id: user_id,
      created_at: created_at.try(:utc)
    }
    ret_hash.merge!(draft_info(record_or_draft))
    ret_hash.merge!(private_hash) if private_api?
    ret_hash
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
      cloud_files: cloud_files_hash,
      thumbs_up: parent.thumbs_up,
      thumbs_down: parent.thumbs_down,
      feedback_count: feedback_count,
      hits: parent.hits,
      tags: fetch_tags,
      seo_data: seo_data
    )
  end

  def draft_info(item)
    ret_hash = {
      title: item.title,
      updated_at: item.updated_at.try(:utc)
    }
    ret_hash.merge!(description_hash(item)) unless @search_context && SEARCH_CONTEXTS_WITHOUT_DESCRIPTION.include?(@search_context)
    ret_hash.merge!(draft_private_hash) if private_api? && @draft.present?
    ret_hash[:draft_present] = @draft.present? if private_api?
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
      language_id: language_id,
      attachments: attachments_hash
    }
    ret_hash.merge!(description_hash(record_or_draft))
  end

  def votes_hash
    {
      helpful: vote_info(:thumbs_up),
      not_helpful: vote_info(:thumbs_down)
    }
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
      normal_attachments = attachments
      normal_attachments = remove_deleted_attachments(normal_attachments + @draft.attachments) if @draft
      normal_attachments.map { |a| AttachmentDecorator.new(a).to_hash }
    end

    def cloud_files_hash
      cloud_attachments = cloud_files
      cloud_attachments = remove_deleted_attachments(cloud_attachments + @draft.cloud_files, :cloud_files) if @draft
      cloud_attachments.map { |a| CloudFileDecorator.new(a).to_hash }
    end

    def description_hash(item)
      {
        description: item.description,
        description_text: item.is_a?(Solution::Article) ? desc_un_html : un_html(item.description)
      }
    end

    def private_hash
      ret_hash = {
        folder_visibility: parent.solution_folder_meta.visibility,
        path: record.to_param,
        modified_at: modified_at.try(:utc),
        modified_by: modified_by,
        language_id: language_id
      }
      ret_hash.merge!(visibility_hash)
      ret_hash
    end

    def draft_private_hash
      {
        draft_locked: @draft.locked?,
        draft_modified_by: @draft.user_id,
        draft_modified_at: @draft.modified_at.try(:utc),
        draft_updated_at: @draft.updated_at.try(:utc)
      }
    end

    def record_or_draft
      @draft || (record.status == Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft] ? draft : record)
    end

    def category_id
      @draft.try(:category_meta_id) || parent.solution_category_meta.id
    end

    def remove_deleted_attachments(attachments, type = :attachments)
      if @draft.meta.present? && @draft.meta[:deleted_attachments].present? && @draft.meta[:deleted_attachments][type].present?
        deleted_att_ids = @draft.meta[:deleted_attachments][type]
        attachments = attachments.reject { |a| deleted_att_ids.include?(a.id) }
      end
      attachments
    end

    def feedback_count
      @feedback_count ||= article_ticket.preload(:ticketable).reject { |article| article.ticketable.spam_or_deleted? }.count
    end

    def vote_info(vote_type)
      users = voters.where('votes.vote = ?', Solution::Article::VOTES[vote_type]).select('users.id, users.name')
      {
        anonymous: safe_send(vote_type) - users.length,
        users: users.map { |voter| { id: voter.id, name: voter.name } }
      }
    end
end
