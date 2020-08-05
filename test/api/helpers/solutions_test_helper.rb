require Rails.root.join('test', 'api', 'helpers', 'solutions_approvals_test_helper.rb')

module SolutionsTestHelper
  include SolutionsApprovalsTestHelper

  def solution_category_pattern(expected_output = {}, _ignore_extra_keys = true, category)
    result = {
      id: expected_output[:id] || category.parent.id,
      name: expected_output[:name] || category.name,
      description: expected_output[:description] || category.description,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    result[:visible_in_portals] = visible_in_portals_payload(category) if Account.current.has_multiple_portals? || @private_api
    result[:language] = category.language_code if @private_api
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
    result[:contact_segment_ids] = folder.solution_folder_meta.contact_filter_ids if folder.parent.visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:contact_segment]
    result[:company_segment_ids] = folder.solution_folder_meta.company_filter_ids if folder.parent.visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_segment]
    if omni_bundle_enabled?
      result[:platforms] = expected_output[:platforms].presence || platform_response(false, folder.parent.solution_platform_mapping)
      result[:tags] = if expected_output[:tags].present?
                        expected_output[:tags]
                      elsif folder.parent.tags.present?
                        folder.parent.tags.pluck(:name)
                      else
                        []
                      end
      result[:icon] = folder.parent.icon.present? ? AttachmentDecorator.new(folder.parent.icon).to_hash : {}
    end
    result
  end

  def solution_folder_pattern_index_channel_api(folder, _expected_output = {}, _ignore_extra_keys = true)
    result = solution_folder_pattern(expected_output = {}, ignore_extra_keys = true, folder)
    result[:article_order] = folder.parent.article_order
    result[:position] = folder.parent.position
    result[:language] = folder.language_code
    result
  end

  def solution_folder_pattern_index(_expected_output = {}, _ignore_extra_keys = true, folder)
    solution_folder_pattern(expected_output = {}, ignore_extra_keys = true, folder).except(:category_id)
  end

  def solution_folder_pattern_private(_expected_output = {}, _ignore_extra_keys = true, folder)
    result = solution_folder_pattern({}, true, folder)
    result[:article_order] = folder.parent.article_order
    result[:position] = folder.parent.position
    result[:language] = folder.language_code
    result[:platforms] = _expected_output[:platforms].presence || platform_response(true, folder.parent.solution_platform_mapping) if omni_bundle_enabled?
    result
  end

  def solution_article_pattern(expected_output = {}, _ignore_extra_keys = true, article)
    expected_tags = expected_output[:tags] || nil

    resp = {
      id: expected_output[:id] || article.parent.id,
      title: expected_output[:title] || article.title,
      agent_id: expected_output[:agent_id] || article.user_id,
      type: expected_output[:type] || article.parent.reload.art_type,
      status: expected_output[:status] || article.status,
      seo_data: expected_output[:seo_data] || seo_data_info(article),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }

    resp[:platforms] = expected_output[:platforms].presence || platform_response(true, article.parent.solution_platform_mapping) if omni_bundle_enabled?

    resp[:suggested] = (expected_output[:suggested] || article.suggested).to_i if Account.current.suggested_articles_count_enabled?
    resp[:tags] = (expected_tags || article.tags.map(&:name)) unless expected_output[:exclude_tags]

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
      unless expected_output[:exclude_description]
        resp[:description] = expected_output[:description] || article.description
        resp[:description_text] = expected_output[:description_text] || article.desc_un_html
      end
      unless expected_output[:exclude_attachments]
        resp[:attachments] = Array
        resp[:cloud_files] = Array
      end
      resp[:feedback_count] = expected_output[:feedback_count] || article.tickets.unresolved.reject(&:spam_or_deleted?).count
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
      hits: expected_output[:hits] || article.solution_article_meta.hits,
      status: expected_output[:status] || article.status,
      seo_data: expected_output[:seo_data] || seo_data_info(article),
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }

    if Account.current.omni_bundle_account? && Account.current.launched?(:kbase_omni_bundle)
      resp[:platforms] = if expected_output[:platforms].present?
                           expected_output[:platforms]
                         elsif article.parent.solution_platform_mapping.present?
                           article.parent.solution_platform_mapping.to_hash
                         else
                           SolutionPlatformMapping.default_platform_values_hash
                         end
    end

    resp[:suggested] = (expected_output[:suggested] || article.suggested).to_i if Account.current.suggested_articles_count_enabled?
    resp[:tags] = (expected_tags || article.tags.map(&:name)) unless expected_output[:exclude_tags]

    cat_folder = if article.parent.reload.solution_category_meta.is_default
                   { source: 'kbase_email' }
                 else
                   { category_id: expected_output[:category_id] || article.parent.reload.solution_category_meta.id,
                     folder_id: expected_output[:folder_id] || article.parent.reload.solution_folder_meta.id }
                 end
    resp.merge!(cat_folder)

    unless expected_output[:action] == :filter
      unless expected_output[:exclude_description]
        resp[:description] = expected_output[:description] || draft.description
        resp[:description_text] = expected_output[:description_text] || UnicodeSanitizer.remove_4byte_chars(Helpdesk::HTMLSanitizer.plain(draft.draft_body.description))
      end
      unless expected_output[:exclude_attachments]
        resp[:attachments] = Array
        resp[:cloud_files] = Array
      end
      resp[:feedback_count] = expected_output[:feedback_count] || article.tickets.unresolved.reject(&:spam_or_deleted?).count
    end
    resp
  end

  def channel_api_solution_article_pattern(article)
    ret_hash = omni_bundle_enabled? ? private_api_solution_article_pattern(article, { exclude_description: true, exclude_attachments: true }, ignore_extra_keys = true, user = nil, channel_api = true) : private_api_solution_article_pattern(article, expected_output = {}, ignore_extra_keys = true, user = nil, channel_api = true)
    ret_hash[:language_id] = article.language_id
    if ret_hash[:status] == Solution::Constants::STATUS_KEYS_BY_TOKEN[:published]
      ret_hash[:published_by] = article.recent_author && article.recent_author.helpdesk_agent ? article.recent_author.try(:name) : nil
      ret_hash[:published_at] = article.modified_at.try(:utc)
    end
    if omni_bundle_enabled?
      ret_hash[:folder_visibility] = article.parent.solution_folder_meta.visibility
      ret_hash[:path] = article.to_param
      ret_hash[:modified_at] = article.modified_at.try(:utc)
      ret_hash[:modified_by] = article.modified_by
    end
    ret_hash[:platforms] = platform_response(false, article.parent.solution_platform_mapping) if omni_bundle_enabled?
    return ret_hash unless @enrich_response

    article = article.reload
    ret_hash[:author_id] = article.user && article.user.helpdesk_agent ? article.user_id : nil
    ret_hash[:author_name] = article.user && article.user.helpdesk_agent ? article.user.try(:name) : nil
    draft = expected_output[:exclude_draft] ? nil : article.draft
    ret_hash[:draft_present] = draft.present?
    folder_hash = enriched_folder_pattern(article.solution_folder_meta, article.language_key)
    category_hash = enriched_category_pattern(article.solution_folder_meta.solution_category_meta, article.language_key)
    ret_hash[:folder] = folder_hash if folder_hash
    ret_hash[:category] = category_hash if category_hash

    if Account.current.multilingual?
      ret_hash[:outdated] = article.outdated
      ret_hash[:language_name] = article.language.name
    end

    ret_hash
  end

  def solution_article_pattern_index(_expected_output = {}, _ignore_extra_keys = true, article)
    solution_article_pattern(expected_output = {}, ignore_extra_keys = true, article)
  end

  def construct_convo_payload(article, time_now)
    article.reload
    [{
      Type: 'article',
      ConvoId: format('%{article_meta_id}-%{lang_code}', article_meta_id: article.parent_id, lang_code: article.language_code),
      UserId: User.current.id.to_s,
      exp: (time_now.to_i + 1_296_000)
    },
     { typ: 'JWT', alg: 'HS256' }]
  end

  def decrypted_convo_token(convo_token)
    JWT.decode(convo_token, CollabConfig['secret_key'])
  end

  def private_api_solution_article_pattern(article, expected_output = {}, ignore_extra_keys = true, user = nil, channel_api = false)
    article.reload
    draft = expected_output[:exclude_draft] ? nil : article.draft
    ret_hash = if draft
                 solution_article_draft_pattern(expected_output, ignore_extra_keys, article, draft)
               else
                 solution_article_pattern(expected_output, ignore_extra_keys, article)
               end
    unless channel_api
      if draft
        ret_hash[:draft_locked] = draft.locked?
        ret_hash[:draft_modified_by] = draft.user_id
        ret_hash[:draft_modified_at] = %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
        ret_hash[:draft_updated_at] = %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
      end
      ret_hash[:folder_visibility] = article.solution_folder_meta.visibility
      ret_hash[:path] = (expected_output[:path] || article.to_param)
      ret_hash[:modified_at] = %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
      ret_hash[:modified_by] = article.modified_by
      ret_hash[:language_id] = article.language_id
      ret_hash[:visibility] = { user.id => article.parent.visible?(user) || false } if user
      ret_hash[:translation_summary] = translation_summary_pattern(article.parent) if @account.multilingual? && expected_output[:action] != :filter && !expected_output[:exclude_translation_summary]
      ret_hash[:draft_present] = expected_output[:draft_present] || draft.present?
      ret_hash[:outdated] = article.outdated if @account.multilingual?
    end
    ret_hash[:language] = article.language_code
    if expected_output[:action] == :filter
      ret_hash[:last_modifier] = ret_hash[:draft_modified_by] || ret_hash[:modified_by]
      ret_hash[:last_modified_at] = ret_hash[:draft_modified_at] || ret_hash[:modified_at]
    end

    if Account.current.article_approval_workflow_enabled?
      ret_hash[:approval_data] = { approval_status: approval_record(article.parent).try(:approval_status), approver_id: approver_record(article.parent).try(:approver_id), user_id: approval_record(article.parent).try(:user_id) }
    end

    ret_hash
  end

  def private_api_solution_article_index_pattern(article, expected_output = {}, ignore_extra_keys = true, user = nil)
    private_api_solution_article_pattern(article, expected_output, ignore_extra_keys, user).except!(:draft_present, :translation_summary)
  end

  def article_content_pattern(article, expected_output = {})
    {
      id: expected_output[:id] || article.parent.id,
      description: expected_output[:description] || article.description,
      description_text: expected_output[:description_text] || article.desc_un_html,
      language_id: expected_output[:language_id] || article.language_id,
      language: Language.find(expected_output[:language_id] || article.language_id).code,
      attachments: Array
    }
  end

  def widget_portal_link(article, help_widget)
    widget_product_id = help_widget.try(:product_id)

    portal = begin
      if widget_product_id
        Account.current.portals.where(product_id: widget_product_id).first
      else
        Account.current.main_portal_from_cache
      end
    end
    return nil unless portal.try(:has_solution_category?, article.parent.solution_category_meta.id)

    url_options = { host: portal.host, protocol: portal.url_protocol }
    url_options[:url_locale] = article.language.code if Account.current.multilingual?
    Rails.application.routes.url_helpers.support_solutions_article_url(article, url_options)
  end

  def widget_article_show_pattern(article, help_widget = nil)
    widget_article_search_pattern(article).merge(
      attachments: widget_attachment_pattern(article.attachments),
      description: article.description,
      meta: {
        portal_link: widget_portal_link(article, help_widget)
      }
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

  def setup_multilingual(supported_languages = ['es', 'ru-RU'])
    Account.current.add_feature(:multi_language)
    Account.current.features.enable_multilingual.create
    additional = Account.current.account_additional_settings
    additional.supported_languages = supported_languages
    additional.save
  end

  def summary_preload_options(language)
    [solution_category_meta: [:portal_solution_categories, solution_folder_meta: [:"#{language.to_key}_folder", { solution_article_meta: :"#{language.to_key}_article" }]]]
  end

  def summary_pattern(portal_id, language)
    portal = Account.current.portals.where(id: portal_id).first
    portal.solution_categories.joins(:solution_category_meta).where('solution_category_meta.is_default = ? AND language_id = ?', false, language.id).preload(summary_preload_options(language)).map { |category| category_summary_pattern(category, portal_id, language) }
  end

  def category_summary_pattern(category, portal_id, language)
    {
      id: category.parent_id,
      name: category.name,
      language: category.language_code,
      folders_count: folders_count(category, language),
      position: category.parent.portal_solution_categories.select { |portal_solution_category| portal_solution_category.portal_id == portal_id }.first.position,
      folders: current_language_folders(category, language).first(::SolutionConstants::SUMMARY_LIMIT).map { |folder| folder_summary_pattern(folder, language) }
    }
  end

  def current_language_folders(category, language)
    category.solution_folder_meta.map { |folder_meta| folder_meta.safe_send("#{language.to_key}_folder") }.compact
  end

  def folders_count(category, language)
    current_language_folders(category, language).length
  end

  def folder_summary_pattern(folder, language)
    {
      id: folder.parent_id,
      name: folder.name,
      language: folder.language_code,
      articles_count: articles_count(folder, language),
      position: folder.parent.position
    }
  end

  def current_language_articles(folder, language)
    folder.solution_article_meta.map { |article_meta| article_meta.safe_send("#{language.to_key}_article") }.compact
  end

  def articles_count(folder, language)
    current_language_articles(folder, language).length
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
    @drafts = fetch_drafts
    @folders = fetch_folders(language_id)
    @approvals = fetch_approvals
    @my_drafts = @drafts.empty? ? [] : @drafts.where(user_id: User.current.id)
    @my_drafts = fetch_my_drafts if Account.current.article_approval_workflow_enabled?
    @published_articles = fetch_published_articles
    @all_feedback = Account.current.article_tickets.select(:id).where(article_id: get_article_ids(@articles), ticketable_type: 'Helpdesk::Ticket').reject { |article_ticket| article_ticket.ticketable.spam_or_deleted? }
    @my_feedback = Account.current.article_tickets.select(:id).where(article_id: get_article_ids(@articles.select { |article| article.user_id == User.current.id }), ticketable_type: 'Helpdesk::Ticket').reject { |article_ticket| article_ticket.ticketable.spam_or_deleted? }
    @orphan_categories = fetch_unassociated_categories.map { |category| unassociated_category_pattern(category) }
    response.api_root_key = :quick_views
    result = {
      all_categories: @categories.count,
      all_folders: @folders.count,
      all_articles: @articles.count,
      all_drafts: @drafts.count - @approvals.count,
      my_drafts: @my_drafts.count,
      published: @published_articles.count,
      all_feedback: @all_feedback.count,
      my_feedback: @my_feedback.count,
      unassociated_categories: @orphan_categories,
      unassociated_categories_count: @orphan_categories.count
    }

    if language_id != Language.for_current_account.id
      result[:outdated] = @articles.select { |article| article.outdated == true }.size
      result[:not_translated] = @article_meta.size - @articles.size
    end
    if Account.current.article_approval_workflow_enabled?
      result[:in_review] = Account.current.helpdesk_approvals.where(approvable_id: get_article_ids(@articles), approvable_type: 'Solution::Article', approval_status: Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:in_review]).count
      result[:approved] = Account.current.helpdesk_approvals.where(approvable_id: get_article_ids(@articles), approvable_type: 'Solution::Article', approval_status: Helpdesk::ApprovalConstants::STATUS_KEYS_BY_TOKEN[:approved]).count
    end
    result[:templates] = Account.current.solution_templates.where(is_active: true).count if Account.current.solutions_templates_enabled?
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

  def fetch_folders(language_id)
    folders_meta = []
    return [] if @category_meta.empty?

    @category_meta.each do |categ_meta|
      folders_meta << categ_meta.solution_folder_meta unless categ_meta.is_default
    end
    folders_meta.flatten!
    Account.current.solution_folders.where(parent_id: folders_meta.map(&:id), language_id: language_id)
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

  def fetch_approvals
    return [] if @articles.empty?

    article_ids = get_article_ids(@articles)
    Account.current.helpdesk_approvals.select([:id, :user_id]).where(approvable_id: article_ids)
  end

  def fetch_my_drafts
    return [] if @my_drafts.empty?

    @my_drafts.joins('LEFT JOIN helpdesk_approvals ON solution_drafts.article_id = helpdesk_approvals.approvable_id').where('helpdesk_approvals.id is NULL')
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
      errors: value.is_a?(Array) ? value : [value]
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

  def approval_data_validation_error_pattern(field, code)
    {
      description: 'Validation failed',
      errors: [
        {
          field: 'approval_data',
          nested_field: "approval_data.#{field}",
          message: :string,
          code: code.to_s
        }
      ]
    }
  end

  def cumulative_attachment_size_validation_error_pattern(current_size, cumulative_size)
    {
      description: 'Validation failed',
      errors: [
        {
          field: 'attachments_list',
          message: "Total attachment(s) size is #{current_size}MB, it should not exceed #{cumulative_size}MB",
          code: 'invalid_size'
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

  def translation_summary_pattern(article_meta)
    result = {}
    article_meta.solution_articles.preload(:draft, :helpdesk_approval).each do |article|
      info = { available: true, draft_present: article.draft_present?, outdated: article.outdated, published: article.published? }
      info[:approval_status] = article.helpdesk_approval.try(:approval_status) if Account.current.article_approval_workflow_enabled?
      result[article.language_code] = info
    end

    Account.current.all_language_objects.each do |language|
      result[language.code] = { available: false, draft_present: false, outdated: false, published: false, approval_status: nil } unless result.key?(language.code)
    end
    result
  end

  def seo_data_info(article)
    seo_values = {
      meta_title: article.seo_data['meta_title'] || '',
      meta_description: article.seo_data['meta_description'] || ''
    }
    seo_values[:meta_keywords] = article.seo_data['meta_keywords'] if article.seo_data['meta_keywords']
    seo_values
  end

  def vote_info(article, vote_type)
    users = article.voters.where('votes.vote = ?', Solution::Article::VOTES[vote_type]).select('users.id, users.name')
    {
      anonymous: article.safe_send(vote_type) - users.length,
      users: users.map { |voter| { id: voter.id, name: voter.name } }
    }
  end

  def untranslated_article_pattern(article, lang_code)
    ret_hash = {
      id: article.parent_id,
      title: (article.draft || article).title,
      status: article.status,
      draft_present: article.draft.present?,
      language: article.language_code,
      category: untranslated_category_pattern(article.solution_folder_meta.solution_category_meta, lang_code),
      folder: untranslated_folder_pattern(article.solution_folder_meta, lang_code)
    }

    if Account.current.article_approval_workflow_enabled?
      ret_hash[:approval_data] = { approval_status: approval_record(article.parent).try(:approval_status), approver_id: approver_record(article.parent).try(:approver_id), user_id: approval_record(article.parent).try(:user_id) }
    end
    ret_hash
  end

  def untranslated_folder_pattern(folder_meta, lang_code)
    folder = folder_meta.safe_send("#{lang_code}_available?") ? folder_meta.safe_send("#{lang_code}_folder") : folder_meta.primary_folder
    {
      id: folder_meta.id,
      name: folder.name,
      language: folder.language_code
    }
  end

  def enriched_folder_pattern(folder_meta, lang_key)
    folder = folder_meta.safe_send("#{lang_key}_available?") ? folder_meta.safe_send("#{lang_key}_folder") : folder_meta.primary_folder
    unless folder_meta.is_default
      resp_hash = {
        id: folder.id,
        name: folder.name,
        visibility: folder_meta.visibility
      }
      resp_hash[:company_names] = company_names if folder.visibility == Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:company_users]
      resp_hash
    end
  end

  def enriched_category_pattern(category_meta, lang_key)
    category = category_meta.safe_send("#{lang_key}_available?") ? category_meta.safe_send("#{lang_key}_category") : category_meta.primary_category
    unless category_meta.is_default
      {
        id: category.id,
        name: category.name,
        visible_in_portals: Account.current.portals.where(id: category.parent.portal_solution_categories.pluck(:portal_id)).pluck(:name)
      }
    end
  end

  def untranslated_category_pattern(category_meta, lang_code)
    category = category_meta.safe_send("#{lang_code}_available?") ? category_meta.safe_send("#{lang_code}_category") : category_meta.primary_category
    {
      id: category_meta.id,
      name: category.name,
      language: category.language_code
    }
  end

  def all_account_languages
    (@account || Account.current).supported_languages + ['primary']
  end

  def all_account_language_keys
    (@account || Account.current).supported_languages_objects.map(&:to_key) + ['primary']
  end

  def platform_response(is_private, solution_platform_mapping)
    if is_private
      solution_platform_mapping.present? ? solution_platform_mapping.to_hash : SolutionPlatformMapping.default_platform_values_hash
    else
      solution_platform_mapping.present? ? solution_platform_mapping.enabled_platforms : []
    end
  end

  def omni_bundle_enabled?
    Account.current.omni_bundle_account? && Account.current.launched?(:kbase_omni_bundle)
  end

  def base64_png_image
    "<img src= 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==' alt='Red dot' />"
  end

  def base64_jpeg_image
    '<img src = "data:image/jpeg;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==" alt="Red dot" />'
  end

  def base64_svg_image
    '<img src="data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4NCjwhLS0gR2VuZXJhdG9yOiBBZG9iZSBJbGx1c3RyYXRvciAxNi4wLjAsIFNWRyBFeHBvcnQgUGx1Zy1JbiAuIFNWRyBWZXJzaW9uOiA2LjAwIEJ1aWxkIDApICAtLT4NCjwhRE9DVFlQRSBzdmcgUFVCTElDICItLy9XM0MvL0RURCBTVkcgMS4xLy9FTiIgImh0dHA6Ly93d3cudzMub3JnL0dyYXBoaWNzL1NWRy8xLjEvRFREL3N2ZzExLmR0ZCI+DQo8c3ZnIHZlcnNpb249IjEuMSIgaWQ9IkxheWVyXzEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHg9IjBweCIgeT0iMHB4Ig0KCSB3aWR0aD0iMTI2cHgiIGhlaWdodD0iMTI2cHgiIHZpZXdCb3g9IjAgMCAxMjYgMTI2IiBlbmFibGUtYmFja2dyb3VuZD0ibmV3IDAgMCAxMjYgMTI2IiB4bWw6c3BhY2U9InByZXNlcnZlIj4NCjxnPg0KCTxyZWN0IHg9IjEuMDk1IiB5PSI5OC4yMjQiIHdpZHRoPSIxMjMuODEiIGhlaWdodD0iMTkuMjc1Ii8+DQoJPHJlY3QgeD0iMS4wOTUiIHk9Ijg1Ljc0IiB3aWR0aD0iMTIzLjgxIiBoZWlnaHQ9IjUuMjA1Ii8+DQoJPHBhdGggZD0iTTE4LjQwNCw5NS43MjFjMC43NjcsMCwxLjM4OS0wLjYyMywxLjM4OS0xLjM5cy0wLjYyMi0xLjM4OC0xLjM4OS0xLjM4OEgzLjQ4MWMtMC43NjcsMC0xLjM4OCwwLjYyMS0xLjM4OCwxLjM4OA0KCQlzMC42MjIsMS4zOSwxLjM4OCwxLjM5SDE4LjQwNHoiLz4NCgk8cGF0aCBkPSJNNDQuNDMzLDk1LjcyMWMwLjc2NywwLDEuMzg4LTAuNjIzLDEuMzg4LTEuMzlzLTAuNjIyLTEuMzg4LTEuMzg4LTEuMzg4SDI5LjUxYy0wLjc2NywwLTEuMzg5LDAuNjIxLTEuMzg5LDEuMzg4DQoJCXMwLjYyMiwxLjM5LDEuMzg5LDEuMzlINDQuNDMzeiIvPg0KCTxwYXRoIGQ9Ik03MC40NjEsOTUuNzIxYzAuNzY3LDAsMS4zODgtMC42MjMsMS4zODgtMS4zOXMtMC42MjItMS4zODgtMS4zODgtMS4zODhINTUuNTM5Yy0wLjc2NywwLTEuMzg4LDAuNjIxLTEuMzg4LDEuMzg4DQoJCXMwLjYyMiwxLjM5LDEuMzg4LDEuMzlINzAuNDYxeiIvPg0KCTxwYXRoIGQ9Ik05Ni40OSw5NS43MjFjMC43NjcsMCwxLjM4OS0wLjYyMywxLjM4OS0xLjM5cy0wLjYyMi0xLjM4OC0xLjM4OS0xLjM4OEg4MS41NjdjLTAuNzY3LDAtMS4zODgsMC42MjEtMS4zODgsMS4zODgNCgkJczAuNjIyLDEuMzksMS4zODgsMS4zOUg5Ni40OXoiLz4NCgk8cGF0aCBkPSJNMTIyLjUxOSw5NS43MjFjMC43NjcsMCwxLjM4OS0wLjYyMywxLjM4OS0xLjM5cy0wLjYyMi0xLjM4OC0xLjM4OS0xLjM4OGgtMTQuOTIzYy0wLjc2NywwLTEuMzg4LDAuNjIxLTEuMzg4LDEuMzg4DQoJCXMwLjYyMiwxLjM5LDEuMzg4LDEuMzlIMTIyLjUxOXoiLz4NCgk8cGF0aCBkPSJNNy40MSw4MC45aDUzLjQ0MmMwLjg2MywwLDEuNTYyLTAuNjk5LDEuNTYyLTEuNTYyVjM5LjU0M2MwLTAuODYyLTAuNjk5LTEuNTYzLTEuNTYyLTEuNTYzSDQ1LjMxNHYtNi41MzkNCgkJYzAtMC44NjEtMC42OTgtMS41NjItMS41NjEtMS41NjJIMjMuNDI4Yy0wLjg2MywwLTEuNTYyLDAuNy0xLjU2MiwxLjU2MnY2LjU0SDcuNDFjLTAuODYyLDAtMS41NjIsMC43LTEuNTYyLDEuNTYzdjM5Ljc5NQ0KCQlDNS44NDgsODAuMjAxLDYuNTQ3LDgwLjksNy40MSw4MC45eiBNMzQuNDkyLDU3Ljg3NGgtMS43OTZ2LTYuNzY4aDEuNzk2VjU3Ljg3NHogTTI2LjU2MywzNC41NzRoMTQuMDU1djMuNDA2SDI2LjU2M1YzNC41NzR6DQoJCSBNMTAuNTQ0LDQyLjY3OGg0Ny4xNzN2MTEuOThIMzYuOTQydi00LjAwNmMwLTAuODYzLTAuNjk5LTEuNTYzLTEuNTYyLTEuNTYzaC0zLjU4MmMtMC44NjMsMC0xLjU2MiwwLjY5OS0xLjU2MiwxLjU2M3Y0LjAwNg0KCQlIMTAuNTQ0VjQyLjY3OHoiLz4NCgk8cGF0aCBkPSJNNjguNzM0LDgwLjloNDkuOTU4YzAuODA3LDAsMS40Ni0wLjY1MywxLjQ2LTEuNDZWMTcuNTM0YzAtMC44MDYtMC42NTMtMS40NTktMS40Ni0xLjQ1OWgtMTQuNTI0VjkuOTYxDQoJCWMwLTAuODA3LTAuNjUzLTEuNDYtMS40Ni0xLjQ2aC0xOWMtMC44MDcsMC0xLjQ2LDAuNjUzLTEuNDYsMS40NnY2LjExNUg2OC43MzRjLTAuODA3LDAtMS40NiwwLjY1My0xLjQ2LDEuNDU5Vjc5LjQ0DQoJCUM2Ny4yNzQsODAuMjQ3LDY3LjkyNyw4MC45LDY4LjczNCw4MC45eiBNODYuNjM4LDEyLjg5aDEzLjEzOXYzLjE4Nkg4Ni42MzhWMTIuODl6Ii8+DQo8L2c+DQo8L3N2Zz4NCg=="/>'
  end

  def base64_gif_image
    '<img src="data:image/gif;base64,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">'
  end

  def base64_html_text
    '<iframe src="data:text/html;base64,PHA+RHVtbXk8L3A+">The “iframe” tag is not supported by your browser.</iframe>'
  end

  def base64_plain_text
    '<iframe src="data:text/plain;base64,VGhpcyBpcyB0byB0ZXN0IGJhc2U2NA==">The “iframe” tag is not supported by your browser.</iframe>'
  end

  def setup_channel_api
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    yield
  ensure
    CustomRequestStore.unstub(:read)
  end
end
