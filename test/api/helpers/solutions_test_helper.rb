module SolutionsTestHelper
  def solution_category_pattern(expected_output = {}, ignore_extra_keys = true, category)
    result = {
      id: expected_output[:id] || category.parent.id,
      name: expected_output[:name] || category.name,
      description: expected_output[:description] || category.description,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
    }
    result.merge!(visible_in_portals: visible_in_portals_payload(category)) if Account.current.has_multiple_portals? || @private_api
    result
  end

  def solution_folder_pattern(expected_output = {}, ignore_extra_keys = true, folder)
    result = {
      id: expected_output[:id] || folder.parent.id,
      name: expected_output[:name] || folder.name,
      description: expected_output[:description] || folder.description,
      visibility: expected_output[:visibility] || folder.solution_folder_meta.visibility,
      category_id: expected_output[:category_id] || folder.solution_folder_meta.category_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
    }
    result.merge!(company_ids: folder.solution_folder_meta.customer_ids) if folder.parent.visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    result
  end

  def solution_folder_pattern_index(expected_output = {}, ignore_extra_keys = true, folder)
    solution_folder_pattern(expected_output = {}, ignore_extra_keys = true, folder).except(:category_id)
  end

  def solution_folder_pattern_private(expected_output = {}, ignore_extra_keys = true, folder)
    solution_folder_pattern(expected_output = {}, ignore_extra_keys = true, folder).merge!({article_order: folder.parent.article_order, position: folder.parent.position})
  end

  def solution_article_pattern(expected_output = {}, ignore_extra_keys = true, article)

    expected_tags = expected_output[:tags] || nil

    {
      id: expected_output[:id] || article.parent.id,
      title: expected_output[:title] || article.title,
      description: expected_output[:description] || article.description,
      description_text: expected_output[:description_text] || article.desc_un_html,
      agent_id: expected_output[:agent_id] || article.user_id,
      type: expected_output[:type] || article.parent.reload.art_type,
      category_id: expected_output[:category_id] || article.parent.reload.solution_category_meta.id,
      folder_id: expected_output[:folder_id] || article.parent.reload.solution_folder_meta.id,
      thumbs_up: expected_output[:thumbs_up] || article.solution_article_meta.thumbs_up,
      thumbs_down: expected_output[:thumbs_down] || article.solution_article_meta.thumbs_down,
      feedback_count: expected_output[:feedback_count] || article.article_ticket.preload(:ticketable).select { |art| !art.ticketable.spam_or_deleted? }.count,
      hits: expected_output[:hits] || article.solution_article_meta.hits,
      status: expected_output[:status] || article.status,
      tags: expected_tags || article.tags.map(&:name),
      seo_data: expected_output[:seo_data] || article.seo_data,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      attachments: Array,
      cloud_files: Array
    }
  end

  def solution_article_draft_pattern(expected_output = {}, ignore_extra_keys = true, article, draft)
    expected_tags = expected_output[:tags] || nil
    {
      id: expected_output[:id] || article.parent.id,
      title: expected_output[:title] || draft.title,
      description: expected_output[:description] || draft.description,
      description_text: expected_output[:description_text] || Helpdesk::HTMLSanitizer.plain(draft.draft_body.description),
      agent_id: expected_output[:agent_id] || article.user_id,
      type: expected_output[:type] || article.parent.reload.art_type,
      category_id: expected_output[:category_id] || article.parent.reload.solution_category_meta.id,
      folder_id: expected_output[:folder_id] || article.parent.reload.solution_folder_meta.id,
      thumbs_up: expected_output[:thumbs_up] || article.solution_article_meta.thumbs_up,
      thumbs_down: expected_output[:thumbs_down] || article.solution_article_meta.thumbs_down,
      feedback_count: expected_output[:feedback_count] || article.article_ticket.preload(:ticketable).select { |art| !art.ticketable.spam_or_deleted? }.count,
      hits: expected_output[:hits] || article.solution_article_meta.hits,
      status: expected_output[:status] || article.status,
      tags: expected_tags || article.tags.map(&:name),
      seo_data: expected_output[:seo_data] || article.seo_data,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      attachments: Array,
      cloud_files: Array
    }
  end

  def solution_article_pattern_index(expected_output = {}, ignore_extra_keys = true, article)
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
    end
    ret_hash[:draft_present] = expected_output[:draft_present] || draft.present?
    ret_hash[:path] = expected_output[:path] || article.to_param
    ret_hash[:modified_at] = %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    ret_hash[:modified_by] = article.modified_by
    ret_hash[:visibility] = { user.id => article.parent.visible?(user) || false } if user
    ret_hash[:folder_visibility] = article.solution_folder_meta.visibility
    ret_hash[:language_id] = article.language_id
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
    { solution_category: { name: "API V1", description: "API V1 Description" } }.to_json
  end

  def v2_category_payload
    { name: "API V2", description: "API V2 Description" }.to_json
  end

  def v1_folder_payload
    { solution_folder: { name: "API V1", description: "API V1 Description", visibility: 1 } }.to_json
  end

  def v2_folder_payload
    { name: "API V2", description: "API V2 Description", visibility: 1 }.to_json
  end

  def v1_article_payload(folder_id)
    { solution_article: { title: "API V1", description: "API V1 Description", status: 1, art_type: 1, folder_id: folder_id } }.to_json
  end

  def v2_article_payload
    { title: "API V1", description: "API V1 Description", status: 1, type: 1 }.to_json
  end

  def v1_article_update_payload
    { solution_article: { description: "API V1 Description" } }.to_json
  end

  def v2_article_update_payload
    { description: "API V1 Description" }.to_json
  end

  def summary_pattern(portal_id)
    Account.current.solution_category_meta.joins(:portal_solution_categories).where('solution_category_meta.is_default = ? AND portal_solution_categories.portal_id = ?', false, portal_id).order('portal_solution_categories.position').preload([:portal_solution_categories, :primary_category, solution_folder_meta: [:primary_folder, :solution_article_meta]]).map { |category| category_summary_pattern(category, portal_id) }
  end

  def category_summary_pattern(category, portal_id)
    {
      id: category.id,
      name: category.name,
      language_id: category.primary_category.language_id,
      folders_count: category.solution_folder_meta.count,
      folders: category.solution_folder_meta[0..2].map { |folder| folder_summary_pattern(folder) },
      position: category.portal_solution_categories.select { |portal_solution_category| portal_solution_category.portal_id == portal_id }.first.position
    }
  end

  def folder_summary_pattern(folder)
    {
      id: folder.id,
      name: folder.name,
      language_id: folder.primary_folder.language_id,
      articles_count: folder.solution_article_meta.count,
      position: folder.position
    }
  end

  def visible_in_portals_payload(category)
    if @private_api
      category.parent.portal_solution_categories.map {|portal_solution_category| {portal_id: portal_solution_category.portal_id, position: portal_solution_category.position}}
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

  def quick_views_pattern portal_id
    @categories = fetch_categories(portal_id)
    @articles = fetch_articles
    @drafts =  fetch_drafts
    @my_drafts = @drafts.empty? ? [] : @drafts.where(user_id: User.current.id)
    @published_articles = fetch_published_articles
    @all_feedback = Account.current.article_tickets.select(:id).where(article_id: get_article_ids(@articles))
    @my_feedback = Account.current.article_tickets.select(:id).where(article_id: get_article_ids(@articles.select{ |article| article.user_id == User.current.id }))
    @orphan_categories = fetch_unassociated_categories_from_cache || []
    response.api_root_key = :quick_views
    {
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
  end

  def fetch_categories(portal_id)
    @category_meta = Account.current.portals.where(id: portal_id).first.solution_categories_from_cache
    Account.current.solution_categories.where(parent_id: @category_meta.map(&:id), language_id: (Language.current? ? Language.current.id : Language.for_current_account.id))
  end

  def fetch_articles
    return [] if @category_meta.empty?
    article_meta = []
    @category_meta.each do |categ_meta|
      article_meta << categ_meta.solution_article_meta.preload(&:current_article)
    end
    article_meta.flatten!
    Account.current.solution_articles.select([:id,:user_id,:status]).where(parent_id: article_meta.map(&:id), language_id: (Language.current? ? Language.current.id : Language.for_current_account.id))
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

  def fetch_unassociated_categories_from_cache
    CustomMemcacheKeys.fetch(CustomMemcacheKeys::UNASSOCIATED_CATEGORIES % {account_id: Account.current.id}, "Unassociated categories for #{Account.current.id}") do
      associated_category_ids = Account.current.portal_solution_categories.map(&:solution_category_meta_id).uniq
      Account.current.solution_category_meta.select(:id).where('id NOT IN (?)', associated_category_ids)
    end
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
end
