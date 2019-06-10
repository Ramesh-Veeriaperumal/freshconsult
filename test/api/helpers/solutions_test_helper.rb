module SolutionsTestHelper
  def solution_category_pattern(expected_output = {}, _ignore_extra_keys = true, category)
    result = {
      id: expected_output[:id] || category.parent.id,
      name: expected_output[:name] || category.name,
      description: expected_output[:description] || category.description,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    result[:visible_in_portals] = visible_in_portals_payload(category) if Account.current.has_multiple_portals? || @private_api
    result
  end

  def solution_folder_pattern(expected_output = {}, _ignore_extra_keys = true, folder)
    result = {
      id: expected_output[:id] || folder.parent.id,
      name: expected_output[:name] || folder.name,
      description: expected_output[:description] || folder.description,
      visibility: expected_output[:visibility] || folder.solution_folder_meta.visibility,
      category_id: expected_output[:category_id] || folder.solution_folder_meta.category_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    result[:company_ids] = folder.solution_folder_meta.customer_ids if folder.parent.visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    result
  end

  def solution_folder_pattern_index(_expected_output = {}, _ignore_extra_keys = true, folder)
    solution_folder_pattern(expected_output = {}, ignore_extra_keys = true, folder).except(:category_id)
  end

  def solution_folder_pattern_private(_expected_output = {}, _ignore_extra_keys = true, folder)
    solution_folder_pattern(expected_output = {}, ignore_extra_keys = true, folder).merge!(article_order: folder.parent.article_order, position: folder.parent.position)
  end

  def solution_article_pattern(expected_output = {}, _ignore_extra_keys = true, article)
    expected_tags = expected_output[:tags] || nil

    resp = {
      id: expected_output[:id] || article.parent.id,
      title: expected_output[:title] || article.title,
      agent_id: expected_output[:agent_id] || article.user_id,
      type: expected_output[:type] || article.parent.reload.art_type,
      feedback_count: expected_output[:feedback_count] || article.article_ticket.where(ticketable_type: 'Helpdesk::Ticket').preload(:ticketable).reject { |art| art.ticketable.spam_or_deleted? }.count,
      status: expected_output[:status] || article.status,
      tags: expected_tags || article.tags.map(&:name),
      seo_data: expected_output[:seo_data] || article.seo_data,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    cat_folder = if article.parent.reload.solution_category_meta.is_default
                   { source: 'kbase_email' }
                 else
                   { category_id: expected_output[:category_id] || article.parent.reload.solution_category_meta.id,
                     folder_id: expected_output[:folder_id] || article.parent.reload.solution_folder_meta.id }
                 end
    resp.merge!(cat_folder)

    if expected_output[:request_language] && expected_output[:request_language] == true
      resp.merge!(thumbs_up: expected_output[:thumbs_up] || article.thumbs_up,
                  thumbs_down: expected_output[:thumbs_down] || article.thumbs_down,
                  hits: expected_output[:hits] || article.hits)
    else
      resp.merge!(thumbs_up: expected_output[:thumbs_up] || article.solution_article_meta.thumbs_up,
                  thumbs_down: expected_output[:thumbs_down] || article.solution_article_meta.thumbs_down,
                  hits: expected_output[:hits] || article.solution_article_meta.hits)
    end

    unless expected_output[:action] == :filter
      resp.merge!(description: expected_output[:description] || article.description,
                  description_text: expected_output[:description_text] || article.desc_un_html,
                  attachments: Array, cloud_files: Array)
    end
    resp
  end

  def solution_article_draft_pattern(expected_output = {}, _ignore_extra_keys = true, article, draft)
    expected_tags = expected_output[:tags] || nil
    resp = {
      id: expected_output[:id] || article.parent.id,
      title: expected_output[:title] || draft.title,
      agent_id: expected_output[:agent_id] || article.user_id,
      type: expected_output[:type] || article.parent.reload.art_type,
      thumbs_up: expected_output[:thumbs_up] || article.solution_article_meta.thumbs_up,
      thumbs_down: expected_output[:thumbs_down] || article.solution_article_meta.thumbs_down,
      feedback_count: expected_output[:feedback_count] || article.article_ticket.preload(:ticketable).reject { |art| art.ticketable.spam_or_deleted? }.count,
      hits: expected_output[:hits] || article.solution_article_meta.hits,
      status: expected_output[:status] || article.status,
      tags: expected_tags || article.tags.map(&:name),
      seo_data: expected_output[:seo_data] || article.seo_data,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }

    cat_folder = if article.parent.reload.solution_category_meta.is_default
                   { source: 'kbase_email' }
                 else
                   { category_id: expected_output[:category_id] || article.parent.reload.solution_category_meta.id,
                     folder_id: expected_output[:folder_id] || article.parent.reload.solution_folder_meta.id }
                 end
    resp.merge!(cat_folder)

    unless expected_output[:action] == :filter
      resp.merge!(description: expected_output[:description] || draft.description,
                  description_text: expected_output[:description_text] || Helpdesk::HTMLSanitizer.plain(draft.draft_body.description),
                  attachments: Array, cloud_files: Array)
    end
    resp
  end

  def solution_article_pattern_index(_expected_output = {}, _ignore_extra_keys = true, article)
    solution_article_pattern(expected_output = {}, ignore_extra_keys = true, article)
  end

  def private_api_solution_article_pattern(article, expected_output = {}, ignore_extra_keys = true, user = nil, draft = nil)
    ret_hash = if draft
                 solution_article_draft_pattern(expected_output, ignore_extra_keys, article, draft)
               else
                 solution_article_pattern(expected_output, ignore_extra_keys, article)
               end
    if draft
      ret_hash[:draft_locked] = draft.locked?
      ret_hash[:draft_modified_by] = draft.user_id
      ret_hash[:draft_modified_at] = %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
      ret_hash[:draft_updated_at] = %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    end
    ret_hash[:draft_present] = expected_output[:draft_present] || draft.present?
    ret_hash[:path] = expected_output[:path] || article.to_param
    ret_hash[:modified_at] = %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    ret_hash[:modified_by] = article.modified_by
    ret_hash[:visibility] = { user.id => article.parent.visible?(user) || false } if user
    ret_hash[:folder_visibility] = article.solution_folder_meta.visibility
    ret_hash[:language_id] = article.language_id
    if expected_output[:action] == :filter
      ret_hash[:last_modifier] = ret_hash[:draft_modified_by] || ret_hash[:modified_by]
      ret_hash[:last_modified_at] = ret_hash[:draft_modified_at] || ret_hash[:modified_at]
    end
    ret_hash
  end

  def article_content_pattern(article, expected_output = {})
    {
      id: expected_output[:id] || article.parent.id,
      description: expected_output[:description] || article.description,
      description_text: expected_output[:description_text] || article.desc_un_html,
      language_id: expected_output[:language_id] || article.language_id,
      attachments: Array
    }
  end

  def widget_article_show_pattern(article)
    widget_article_search_pattern(article).merge(
      attachments: widget_attachment_pattern(article.attachments),
      description: article.description
    )
  end

  def widget_article_search_pattern(article)
    {
      id: article.parent_id,
      title: article.title,
      modified_at: article.modified_at.try(:utc),
      language_id: article.language_id
    }
  end

  def widget_attachment_pattern(attachments)
    ret = []
    attachments.each do |attachment|
      ret << attachment_pattern(attachment)
    end
    ret
  end

  def v1_category_payload
    { solution_category: { name: 'API V1', description: 'API V1 Description' } }.to_json
  end

  def v2_category_payload
    { name: 'API V2', description: 'API V2 Description' }.to_json
  end

  def v1_folder_payload
    { solution_folder: { name: 'API V1', description: 'API V1 Description', visibility: 1 } }.to_json
  end

  def v2_folder_payload
    { name: 'API V2', description: 'API V2 Description', visibility: 1 }.to_json
  end

  def v1_article_payload(folder_id)
    { solution_article: { title: 'API V1', description: 'API V1 Description', status: 1, art_type: 1, folder_id: folder_id } }.to_json
  end

  def v2_article_payload
    { title: 'API V1', description: 'API V1 Description', status: 1, type: 1 }.to_json
  end

  def v1_article_update_payload
    { solution_article: { description: 'API V1 Description' } }.to_json
  end

  def v2_article_update_payload
    { description: 'API V1 Description' }.to_json
  end

  def setup_multilingual(languages = ['es', 'ru-RU'])
    Account.current.add_feature(:multi_language)
    Account.current.features.enable_multilingual.create
    additional = Account.current.account_additional_settings
    additional.supported_languages = languages
    additional.save
    yield
  ensure
    disable_multilingual
  end

  def disable_multilingual
    Account.current.revoke_feature(:multi_language)
    Account.current.features.enable_multilingual.destroy
  end

  def summary_preload_options(language_code)
    [solution_category_meta: [:portal_solution_categories, solution_folder_meta: [:"#{language_code}_folder", { solution_article_meta: :"#{language_code}_article" }]]]
  end

  def summary_pattern(portal_id, language)
    portal = Account.current.portals.where(id: portal_id).first
    portal.solution_categories.joins(:solution_category_meta).where('solution_category_meta.is_default = ? AND language_id = ?', false, language.id).preload(summary_preload_options(language.code)).map { |category| category_summary_pattern(category, portal_id, language.code) }
  end

  def category_summary_pattern(category, portal_id, language_code)
    {
      id: category.parent_id,
      name: category.name,
      language: category.language_code,
      folders_count: folders_count(category, language_code),
      position: category.parent.portal_solution_categories.select { |portal_solution_category| portal_solution_category.portal_id == portal_id }.first.position,
      folders: current_language_folders(category, language_code).first(::SolutionConstants::SUMMARY_LIMIT).map { |folder| folder_summary_pattern(folder, language_code) }
    }
  end

  def current_language_folders(category, language_code)
    category.solution_folder_meta.map { |folder_meta| folder_meta.safe_send("#{language_code}_folder") }.compact
  end

  def folders_count(category, language_code)
    current_language_folders(category, language_code).length
  end

  def folder_summary_pattern(folder, language_code)
    {
      id: folder.parent_id,
      name: folder.name,
      language: folder.language_code,
      articles_count: articles_count(folder, language_code),
      position: folder.parent.position
    }
  end

  def current_language_articles(folder, language_code)
    folder.solution_article_meta.map { |article_meta| article_meta.safe_send("#{language_code}_article") }.compact
  end

  def articles_count(folder, language_code)
    current_language_articles(folder, language_code).length
  end

  def visible_in_portals_payload(category)
    if @private_api
      category.parent.portal_solution_categories.map { |portal_solution_category| { portal_id: portal_solution_category.portal_id, position: portal_solution_category.position } }
    else
      category.parent.portal_solution_categories.map(&:portal_id)
    end
  end

  def article_params(folder_visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
    category = create_category(portal_id: Account.current.main_portal.id)
    {
      title: 'Test',
      description: 'Test',
      folder_id: create_folder(visibility: folder_visibility, category_id: category.id).id
    }
  end

  def quick_views_pattern(portal_id = nil, language_id = Account.current.language_object.id)
    @categories = fetch_categories(portal_id, language_id)
    @articles = fetch_articles(language_id)
    @drafts =  fetch_drafts
    @my_drafts = @drafts.empty? ? [] : @drafts.where(user_id: User.current.id)
    @published_articles = fetch_published_articles
    @all_feedback = Account.current.article_tickets.select(:id).where(article_id: get_article_ids(@articles), ticketable_type: 'Helpdesk::Ticket').reject { |article_ticket| article_ticket.ticketable.spam_or_deleted? }
    @my_feedback = Account.current.article_tickets.select(:id).where(article_id: get_article_ids(@articles.select { |article| article.user_id == User.current.id }), ticketable_type: 'Helpdesk::Ticket').reject { |article_ticket| article_ticket.ticketable.spam_or_deleted? }
    @orphan_categories = fetch_unassociated_categories.map { |category| unassociated_category_pattern(category) }
    response.api_root_key = :quick_views
    result = {
      all_categories: @categories.count,
      all_articles: @articles.count,
      all_drafts: @drafts.count,
      my_drafts: @my_drafts.count,
      published_articles: @published_articles.count,
      all_feedback: @all_feedback.count,
      my_feedback: @my_feedback.count,
      unassociated_categories: @orphan_categories,
      unassociated_categories_count: @orphan_categories.count
    }

    if language_id != Language.for_current_account.id
      result[:outdated] = @articles.select { |article| article.outdated == true }.size
      result[:not_translated] = @article_meta.size - @articles.size
    end
    result
  end

  def fetch_categories(portal_id, language_id)
    if portal_id.present?
      @category_meta = Account.current.portals.find_by_id(portal_id).public_category_meta.order('portal_solution_categories.position').all
    else
      @category_meta = Account.current.public_category_meta
    end
    portal_categories = Account.current.solution_categories.where(parent_id: @category_meta.map(&:id), language_id: language_id)
    @category_meta += [Account.current.solution_category_meta.where(is_default: true).first]
    portal_categories
  end

  def fetch_articles(language_id)
    @article_meta = []
    return [] if @category_meta.empty?
    @category_meta.each do |categ_meta|
      @article_meta << categ_meta.solution_article_meta.preload(&:current_article)
    end
    @article_meta.flatten!
    Account.current.solution_articles.select([:id, :user_id, :status, :outdated]).where(parent_id: @article_meta.map(&:id), language_id: language_id)
  end

  def fetch_drafts
    return [] if @articles.empty?
    article_ids = get_article_ids(@articles)
    Account.current.solution_drafts.select([:id, :user_id]).where(article_id: article_ids)
  end

  def get_article_ids(articles)
    articles.map(&:id)
  end

  def fetch_published_articles
    return [] if @articles.empty?
    @articles.where(status: Solution::Constants::STATUS_KEYS_BY_TOKEN[:published])
  end

  def fetch_unassociated_categories
    associated_category_ids = Account.current.portal_solution_categories.map(&:solution_category_meta_id).uniq
    @account.solution_categories.where('parent_id NOT IN (?) AND language_id = ?', associated_category_ids, @account.language_object.id)
  end

  def unassociated_category_pattern(category)
    {
      category: {
        id: category.parent_id,
        name: category.name,
        description: category.description
      }
    }
  end

  def validation_error_pattern(value)
    {
      description: 'Validation failed',
      errors: [value]
    }
  end

  def bulk_validation_error_pattern(field, code)
    {
      description: 'Validation failed',
      errors: [
        {
          field: 'properties',
          nested_field: "properties.#{field}",
          message: :string,
          code: code.to_s
        }
      ]
    }
  end

  def votes_pattern(article)
    {
      helpful: vote_info(article, :thumbs_up),
      not_helpful: vote_info(article, :thumbs_down)
    }.to_json
  end

  def vote_info(article, vote_type)
    users = article.voters.where('votes.vote = ?', Solution::Article::VOTES[vote_type]).select('users.id, users.name')
    {
      anonymous: article.safe_send(vote_type) - users.length,
      users: users.map { |voter| { id: voter.id, name: voter.name } }
    }
  end

  def untranslated_article_pattern(article, lang_code)
    {
      id: article.parent_id,
      title: (article.draft || article).title,
      status: article.status,
      draft_present: article.draft.present?,
      language: article.language_code,
      category: untranslated_category_pattern(article.solution_folder_meta.solution_category_meta, lang_code),
      folder: untranslated_folder_pattern(article.solution_folder_meta, lang_code)
    }
  end

  def untranslated_folder_pattern(folder_meta, lang_code)
    folder = folder_meta.safe_send("#{lang_code}_available?") ? folder_meta.safe_send("#{lang_code}_folder") : folder_meta.primary_folder
    {
      id: folder_meta.id,
      name: folder.name,
      language: folder.language_code
    }
  end

  def untranslated_category_pattern(category_meta, lang_code)
    category = category_meta.safe_send("#{lang_code}_available?") ? category_meta.safe_send("#{lang_code}_category") : category_meta.primary_category
    {
      id: category_meta.id,
      name: category.name,
      language: category.language_code
    }
  end
end
