class Solutions::ArticleDecorator < ApiDecorator
  delegate :title, :description, :desc_un_html, :user_id, :status, :seo_data, :language_id,
           :parent, :parent_id, :draft, :attachments, :cloud_files, :article_ticket, :modified_at,
           :modified_by, :id, :to_param, :tags, :voters, :thumbs_up, :thumbs_down, :hits, :tickets, :outdated, :helpdesk_approval,
           :suggested, :user, :solution_folder_meta, :recent_author, to: :record

  SEARCH_CONTEXTS_WITHOUT_DESCRIPTION = [:agent_insert_solution, :filtered_solution_search].freeze
  SPOTLIGHT_SEARCH_CONTEXT = :agent_spotlight_solution

  include SolutionHelper

  def initialize(record, options = {})
    super(record)
    @user = options[:user]
    @search_context = options[:search_context]
    @is_list_page = options[:is_list_page]
    @draft = options[:draft]
    @language_metric = options[:language_metric]
    @lang_code = options[:language_code]
    @prefer_published = options[:prefer_published]
    @exclude_options = options[:exclude]
  end

  def exclude?(param)
    @exclude_options.present? && @exclude_options.include?(param)
  end

  def fetch_tags
    record.tags.map(&:name)
  end

  def un_html(html_string)
    UnicodeSanitizer.remove_4byte_chars(Helpdesk::HTMLSanitizer.plain(html_string))
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
    ret_hash.merge!(private_hash) if private_api? || @search_context
    ret_hash
  end

  def to_search_hash
    result = article_info.merge(
      category_name: category_name,
      folder_name: folder_name
    )
    result[:portal_ids] = category_meta.portal_solution_categories.map(&:portal_id) if private_api? && @search_context == SPOTLIGHT_SEARCH_CONTEXT
    result
  end

  def to_hash
    ret_hash = article_info
    ret_hash[:seo_data] = seo_data_values
    ret_hash[:tags] = fetch_tags unless exclude?(:tags)

    unless @is_list_page || exclude?(:attachments)
      ret_hash[:attachments] = attachments_hash
      ret_hash[:cloud_files] = cloud_files_hash
    end
    ret_hash.merge!(article_metrics)
    ret_hash.merge!(platform_mapping) if allow_chat_platform_attributes?
    ret_hash[:language_id] = language_id if channel_v2_api?
    if private_api?
      ret_hash[:draft_present] = @draft.present?
      ret_hash.merge!(draft_private_hash) if @draft.present?
      ret_hash.merge!(last_modified(ret_hash)) if @is_list_page
      if Account.current.multilingual?
        ret_hash[:translation_summary] = translation_summary_hash if !@is_list_page && !exclude?(:translation_summary)
        ret_hash[:outdated] = outdated
      end
    end
    if (private_api? || channel_v2_api?) && Account.current.article_approval_workflow_enabled?
      ret_hash[:approval_data] = approval_hash
    end
    ret_hash
  end

  def collaboration_hash
    {
      convo_token: Collaboration::Article.new.convo_token(record.parent_id, record.language_code)
    }
  end

  def approval_hash
    { approval_status: approval_record(record).try(:approval_status), approver_id: approver_record(record).try(:approver_id), user_id: approval_record(record).try(:user_id) }
  end

  def draft_user_name
    @draft.user.try(:name) if @draft.user && @draft.user.helpdesk_agent
  end

  def published_details_hash
    pub_hash = {}
    if published?
      pub_hash[:published_by] = record.recent_author && record.recent_author.helpdesk_agent ? record.recent_author.try(:name) : nil
      pub_hash[:published_at] = modified_at.try(:utc)
    end
    pub_hash
  end

  def modified_by_name
    if @draft.present?
      draft_user_name
    else
      record.recent_author.try(:name) if record.recent_author && record.recent_author.helpdesk_agent
    end
  end

  def last_modified_at_time
    @draft.present? ? @draft.modified_at.try(:utc) : modified_at.try(:utc)
  end

  def author_name
    record.user.try(:name)
  end

  def to_export_hash
    export_hash = to_hash.merge!(live: published?,
                                 author_id: nil,
                                 author_name: nil,
                                 status: I18n.t(Solution::Constants::STATUS_NAMES_BY_KEY[@draft.present? ? Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft] : status]),
                                 seo_title: seo_data['meta_title'],
                                 seo_description: seo_data['meta_description'],
                                 modified_at: last_modified_at_time,
                                 language_code: @lang_code)
    if record.user && record.user.helpdesk_agent
      export_hash[:author_id] = record.user_id
      export_hash[:author_name] = author_name
    end
    export_hash[:recent_author_name] = modified_by_name unless exclude?(:recent_author_name)
    export_hash[:tags] = fetch_tags.join(';') unless exclude?(:tags)
    export_hash[:folder_name] = folder_name if export_hash[:folder_id].present? && !exclude?(:folder_name)
    export_hash[:category_name] = category_name if export_hash[:folder_id].present? && !exclude?(:category_name)
    export_hash
  end

  def folder_category_hash
    fc_hash = {}
    # TODO Need to refactor langauge_code and language_key usage(Start from solution_concern - @lang_code).
    # TODO It is required to pass folder as record, not folder_meta. Need to correct it in other places.
    folder_hash = Solutions::FolderDecorator.new(folder).enriched_hash
    fc_hash[:folder] = folder_hash if folder_hash
    category_hash = Solutions::CategoryDecorator.new(category).enriched_hash
    fc_hash[:category] = category_hash if category_hash
    fc_hash
  end

  def enriched_hash
    result = to_hash.merge!(
      author_id: nil,
      author_name: nil,
      language: language_code,
      draft_present: @draft.present?
    )
    result.merge!(published_details_hash)
    if record.user && record.user.helpdesk_agent
      result[:author_id] = record.user_id
      result[:author_name] = author_name
    end
    result.merge!(folder_category_hash) if result[:folder_id].present?
    if Account.current.multilingual?
      result[:outdated] = outdated
      result[:language_name] = language_name
    end
    result
  end

  def to_index_hash
    to_hash.except!(:draft_present, :translation_summary)
  end

  def draft_info(item)
    ret_hash = {
      title: item.title,
      updated_at: item.updated_at.try(:utc)
    }
    ret_hash.merge!(description_hash(item)) unless exclude?(:description) || @is_list_page || (@search_context && SEARCH_CONTEXTS_WITHOUT_DESCRIPTION.include?(@search_context))
    ret_hash
  end

  def visibility_hash
    return {} if @user.blank?
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
    ret_hash = {
      id: parent_id,
      title: record_or_draft.title,
      status: record.status,
      draft_present: @draft.present?,
      language: record.language_code,
      category: Solutions::CategoryDecorator.new(record.solution_folder_meta.solution_category_meta, language_code: @lang_code).untranslated_filter_hash,
      folder: Solutions::FolderDecorator.new(record.solution_folder_meta, language_code: @lang_code).untranslated_filter_hash
    }
    ret_hash[:approval_data] = approval_hash if private_api? && Account.current.article_approval_workflow_enabled?
    ret_hash
  end

  def translation_summary_hash
    result = {}

    parent.solution_articles.preload(:draft, :helpdesk_approval).each do |article|
      info = { available: true, draft_present: article.draft_present?, outdated: article.outdated, published: article.published? }
      info[:approval_status] = article.helpdesk_approval.try(:approval_status) if Account.current.article_approval_workflow_enabled?
      result[article.language_code] = info
    end

    Account.current.all_language_objects.each do |language|
      result[language.code] = { available: false, draft_present: false, outdated: false, published: false, approval_status: nil } unless result.key?(language.code)
    end
    result
  end

  private

    def folder
      solution_folder_meta.safe_send("#{language_key}_available?") ? solution_folder_meta.safe_send("#{language_key}_folder") : solution_folder_meta.primary_folder
    end

    def category
      category_meta = solution_folder_meta.solution_category_meta
      category_meta.safe_send("#{language_key}_available?") ? category_meta.safe_send("#{language_key}_category") : category_meta.primary_category
    end

    def folder_name
      # articles moved from one folder to other may not have folder/category name if not translated.
      record.solution_folder_meta.safe_send("#{language_key}_folder").try(:name)
    end

    def category_meta
      parent.solution_category_meta
    end

    def category_name
      # articles moved from one folder to other may not have folder/category name if not translated.
      category_meta.safe_send("#{language_key}_category").try(:name)
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

    def language_name
      language_object.name
    end

    def attachments_hash
      normal_attachments = valid_attachments(record, @draft)
      normal_attachments.map { |a| AttachmentDecorator.new(a).to_hash }
    end

    def cloud_files_hash
      cloud_attachments = valid_attachments(record, @draft, :cloud_files)
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
        draft_updated_at: @draft.draft_body.present? ? [@draft.updated_at, @draft.draft_body.updated_at].max.try(:utc) : @draft.updated_at.try(:utc)
      }
    end

    def record_or_draft
      (!@prefer_published && @draft.present?) || record.status == Solution::Constants::STATUS_KEYS_BY_TOKEN[:draft] ? draft : record
    end

    def category_and_folder
      if category_meta.is_default
        { source: ::SolutionConstants::KBASE_EMAIL_SOURCE }
      else
        { category_id: category_meta.id,
          folder_id: parent.solution_folder_meta.id }
      end
    end

    def article_metrics
      metrics = {
        thumbs_up: @language_metric ? thumbs_up : parent.thumbs_up,
        thumbs_down: @language_metric ? thumbs_down : parent.thumbs_down,
        hits: @language_metric ? hits : parent.hits
      }

      metrics[:suggested] = suggested.to_i if current_account.suggested_articles_count_enabled?
      # TODO : we need to optimize feedback count as count query, for now we are excluding it for list page
      metrics[:feedback_count] = feedback_count unless @is_list_page
      metrics
    end

    def platform_mapping
      solution_platform_mapping = record.parent.solution_platform_mapping
      platforms = solution_platform_mapping.present? ? solution_platform_mapping.to_hash : SolutionPlatformMapping.default_platform_values_hash

      { platforms: platforms }
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

    def last_modified(resp_hash)
      {
        last_modifier: resp_hash[:draft_modified_by] || resp_hash[:modified_by],
        last_modified_at: resp_hash[:draft_modified_at] || resp_hash[:modified_at]
      }
    end

    def published?
      status == Solution::Constants::STATUS_KEYS_BY_TOKEN[:published]
    end

    def seo_data_values
      seo_values = {
        meta_title: seo_data['meta_title'] || '',
        meta_description: seo_data['meta_description'] || ''
      }
      seo_values[:meta_keywords] = seo_data['meta_keywords'] if seo_data['meta_keywords']
      seo_values
    end

    def approval_record(article)
      return @approval if defined?(@approval)

      @approval = article.helpdesk_approval
    end

    def approver_record(article)
      return @approver if defined?(@approver)

      @approver = approval_record(article).try(:approver_mappings).try(:first)
    end
end
