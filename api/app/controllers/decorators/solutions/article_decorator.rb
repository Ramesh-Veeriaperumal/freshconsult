class Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :seo_data, :language_id,
           :parent, :parent_id, :draft, :attachments, :cloud_files, :article_ticket, :modified_at,
           :modified_by, :id, :to_param, :tags, :voters, :thumbs_up, :thumbs_down, :hits, :tickets, :outdated, to: :record

  SEARCH_CONTEXTS_WITHOUT_DESCRIPTION = [:agent_insert_solution, :filtered_solution_search].freeze

  def initialize(record, options = {})
    super(record)
    @user = options[:user]
    @search_context = options[:search_context]
    @is_list_page = options[:is_list_page]
    @draft = options[:draft]
    @language_metric = options[:language_metric]
    @lang_code = options[:language_code]
    if options[:exclude].present?
      @exclude_description = options[:exclude].include?(:description)
      @exclude_attachments = options[:exclude].include?(:attachments)
      @exclude_tags = options[:exclude].include?(:tags)
    end
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
      status: status,
      agent_id: user_id,
      created_at: created_at.try(:utc)
    }
    ret_hash.merge!(category_and_folder)
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
    ret_hash = article_info
    ret_hash[:seo_data] = seo_data
    ret_hash[:tags] = fetch_tags unless @exclude_tags

    unless @is_list_page || @exclude_attachments
      ret_hash[:attachments] = attachments_hash
      ret_hash[:cloud_files] = cloud_files_hash
    end
    ret_hash.merge!(article_metrics)
    ret_hash[:language_id] = language_id if channel_v2_api?
    if private_api?
      ret_hash[:draft_present] = @draft.present?
      ret_hash.merge!(draft_private_hash) if @draft.present?
      ret_hash.merge!(last_modified(ret_hash)) if @is_list_page
      if Account.current.multilingual?
        ret_hash[:translation_summary] = translation_summary_hash
        ret_hash[:outdated] = outdated
      end
    end
    ret_hash
  end

  def to_index_hash
    to_hash.except!(:draft_present, :translation_summary)
  end

  def draft_info(item)
    ret_hash = {
      title: item.title,
      updated_at: item.updated_at.try(:utc)
    }
    ret_hash.merge!(description_hash(item)) unless @exclude_description || @is_list_page || (@search_context && SEARCH_CONTEXTS_WITHOUT_DESCRIPTION.include?(@search_context))
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
      language: language_code,
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

  def untranslated_filter_hash
    {
      id: parent_id,
      title: record_or_draft.title,
      status: record.status,
      draft_present: @draft.present?,
      language: record.language_code,
      category: Solutions::CategoryDecorator.new(record.solution_folder_meta.solution_category_meta, language_code: @lang_code).untranslated_filter_hash,
      folder: Solutions::FolderDecorator.new(record.solution_folder_meta, language_code: @lang_code).untranslated_filter_hash
    }
  end

  def translation_summary_hash
    result = {}
    Account.current.all_language_objects.each do |language|
      result[language.code] = translation_info(language)
    end
    result
  end

  private

    def folder_name
      record.solution_folder_meta.safe_send("#{language_key}_folder").name
    end

    def category_name
      record.solution_folder_meta.solution_category_meta.safe_send("#{language_key}_category").name
    end

    def language_object
      @language_object ||= Language.find(language_id)
    end

    # NOTE: Language code and key is different for zh-TW
    def language_key
      language_object.to_key
    end

    def language_code
      language_object.code
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
        language_id: language_id,
        language: language_code
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

    def category_and_folder
      @category_meta = parent.solution_category_meta
      if @category_meta.is_default
        { :source => ::SolutionConstants::KBASE_EMAIL_SOURCE }
      else
        { category_id: @draft.try(:category_meta_id) || @category_meta.id,
          folder_id: parent.solution_folder_meta.id }
      end
    end

    def article_metrics
      {
        feedback_count: feedback_count,
        thumbs_up: @language_metric ? thumbs_up : parent.thumbs_up,
        thumbs_down: @language_metric ? thumbs_down : parent.thumbs_down,
        hits: @language_metric ? hits : parent.hits
      }
    end

    def remove_deleted_attachments(attachments, type = :attachments)
      if @draft.meta.present? && @draft.meta[:deleted_attachments].present? && @draft.meta[:deleted_attachments][type].present?
        deleted_att_ids = @draft.meta[:deleted_attachments][type]
        attachments = attachments.reject { |a| deleted_att_ids.include?(a.id) }
      end
      attachments
    end

    def vote_info(vote_type)
      users = voters.where('votes.vote = ?', Solution::Article::VOTES[vote_type]).select('users.id, users.name')
      {
        anonymous: safe_send(vote_type) - users.length,
        users: users.map { |voter| { id: voter.id, name: voter.name } }
      }
    end

    def feedback_count
      @feedback_count ||= tickets.unresolved.reject(&:spam_or_deleted?).count
    end

    def last_modified resp_hash
      {
        last_modifier: resp_hash[:draft_modified_by] || resp_hash[:modified_by],
        last_modified_at: resp_hash[:draft_modified_at] || resp_hash[:modified_at]
      }
    end

    def published?
      status == Solution::Constants::STATUS_KEYS_BY_TOKEN[:published]
    end

    def translation_info(language)
      language_key = language.to_key
      # binarize sync happens on another object reference rather than record.parent, thus the value won't be updated here for current language article.
      if language.id == language_id
        {
          available: true,
          draft_present: @draft.present?,
          outdated: outdated,
          published: published?
        }
      else
        {
          available: parent.safe_send("#{language_key}_available?"),
          draft_present: parent.safe_send("#{language_key}_draft_present?"),
          outdated: parent.safe_send("#{language_key}_outdated?"),
          published: parent.safe_send("#{language_key}_published?")
        }
      end
    end
end
