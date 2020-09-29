['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

module ModelsSolutionsTestHelper
  include SolutionsHelper
  include SolutionBuilderHelper

  def create_portal(params = {})
    @account.enable_setting(:skip_portal_cname_chk)
    test_portal = FactoryGirl.build(:portal,
      name: params[:portal_name] || Faker::Name.name,
      portal_url: params[:portal_url] || '',
      language: 'en',
      forum_category_ids: (params[:forum_category_ids] || ['']),
      solution_category_metum_ids: (params[:solution_category_metum_ids] || params[:solution_category_ids] || ['']),
      account_id: @account.id,
      preferences: {
        logo_link: '',
        contact_info: '',
        header_color: '#252525',
        tab_color: '#006063',
        bg_color: '#efefef'
      })

    test_portal.save!
    test_portal
  end

  def update_portal(portal)
    portal.name = Faker::Name.name
    portal.save(validate: false)
  end

  def add_new_category
    portal = create_portal
    create_category({
      name: "#{Faker::Lorem.sentence(3)}",
      description: "#{Faker::Lorem.sentence(3)}",
      is_default: false,
      portal_ids: [portal.id]
    }).primary_category
  end

  def add_new_folder
    category = add_new_category
    create_folder({
      name: "#{Faker::Lorem.sentence(3)}",
      description: "#{Faker::Lorem.sentence(3)}",
      visibility: 1,
      category_id: category.id
    }).primary_folder
  end

  def add_new_article
    folder = add_new_folder
    create_article({
      title: "#{Faker::Lorem.sentence(3)}",
      description: "#{Faker::Lorem.sentence(3)}",
      folder_id: folder.id,
      user_id: @agent.id,
      status: '2',
      art_type: '1'
    }).primary_article
  end

  def add_article_ticket(article, ticket)
    article_ticket = ticket.build_article_ticket(article_id: article.id)
    article_ticket.save
    article_ticket
  end

  def create_tag(account, options = {})
    tag_params = { name: options[:name] || SecureRandom.uuid + Faker::Name.name, tag_uses_count: 1, account_id: account.id }
    test_tag = FactoryGirl.build(:tag, tag_params)
    test_tag.save
    test_tag
  end

  def central_publish_category_pattern(category)
    parent = category.parent
    {
      category_id: category.id,
      id: category.parent_id,
      name: category.name,
      description: category.description,
      language_id: category.language_id,
      language_code: category.language_code,
      account_id: category.account_id,
      created_at: [category.created_at, parent.created_at].max.try(:utc).try(:iso8601),
      updated_at: [category.updated_at, parent.updated_at].max.try(:utc).try(:iso8601)
    }
  end

  def central_publish_folder_pattern(folder)
    parent = folder.parent
    {
      folder_id: folder.id,
      id: folder.parent_id,
      name: folder.name,
      description: folder.description,
      visibility: parent.visibility,
      article_order: parent.article_order,
      category_id: parent.solution_category_meta_id,
      language_id: folder.language_id,
      language_code: folder.language_code,
      account_id: folder.account_id,
      created_at: [folder.created_at, parent.created_at].max.try(:utc).try(:iso8601),
      updated_at: [folder.updated_at, parent.updated_at].max.try(:utc).try(:iso8601)
    }
  end

  def central_publish_article_pattern(article)
    parent = article.parent
    {
      article_id: article.id,
      id: article.parent_id,
      title: article.title,
      description: article.description,
      description_text: article.desc_un_html,
      status: article.status,
      outdated: article.outdated,
      agent_id: article.user_id,
      type: parent.art_type,
      category_id: parent.solution_category_meta.id,
      folder_id: parent.solution_folder_meta_id,
      thumbs_up: parent.thumbs_up,
      thumbs_down: parent.thumbs_down,
      hits: parent.hits,
      tags: article.tags,
      seo_data: article.seo_data,
      language_id: article.language_id,
      language_code: article.language_code,
      account_id: article.account_id,
      created_at: [article.created_at, parent.created_at].max.try(:utc).try(:iso8601),
      updated_at: [article.updated_at, parent.updated_at].max.try(:utc).try(:iso8601),
      modified_at: article.modified_at.try(:utc).try(:iso8601),
      modified_by: article.modified_by,
      draft_exists: article.draft_present? ? 1 : 0,
      draft_modified_at: article.draft.try(:modified_at).try(:utc).try(:iso8601),
      draft_modified_by: article.draft.try(:user_id),
      published_at: article.status == 2 ? article.modified_at.try(:utc).try(:iso8601) : nil,
      published_by: article.status == 2 ? article.modified_by : nil,
      approval_status: article.helpdesk_approval.try(:approval_status),
      approved_by: article.helpdesk_approval.try(:approved_by),
      approved_at: article.helpdesk_approval.try(:approved_at)
    }
  end

  def central_publish_article_ticket_pattern(article_ticket)
    {
      id: article_ticket.id,
      article_id: article_ticket.article_id,
      account_id: article_ticket.account_id,
      ticketable_type: article_ticket.ticketable_type,
      ticketable_id: article_ticket.ticketable_id
    }
  end

  def central_publish_article_ticket_event_info
    current_portal = Portal.current || Account.current.main_portal
    {
      source_type: 1,
      source_id: current_portal.id
    }
  end

  def central_publish_article_interactions_pattern(article)
    parent = article.parent
    {
      id: article.parent_id,
      article_id: article.id,
      thumbs_up: parent.thumbs_up,
      thumbs_down: parent.thumbs_down,
      hits: parent.hits,
      article_thumbs_up: article.thumbs_up,
      article_thumbs_down: article.thumbs_down,
      article_hits: article.hits,
      article_suggested: article.suggested,
      account_id: article.account_id
    }
  end

  def central_publish_article_interactions_event_info
    current_portal = Portal.current || Account.current.main_portal
    {
      source_type: 1,
      source_id: current_portal.id,
      ip_address: Thread.current[:current_ip]
    }
  end

  def central_publish_portal_solution_category_pattern(portal_solution_category)
    {
      id: portal_solution_category.id,
      portal_id: portal_solution_category.portal_id,
      account_id: portal_solution_category.account_id,
      solution_category_meta_id: portal_solution_category.solution_category_meta_id,
      bot_id: portal_solution_category.bot_id
    }
  end

  def central_publish_portal_solution_category_destroy(portal_solution_category)
    {
      id: portal_solution_category.id,
      portal_id: portal_solution_category.portal_id,
      solution_category_meta_id: portal_solution_category.solution_category_meta_id,
      account_id: portal_solution_category.account_id
    }
  end

  def setup_multilingual(supported_languages = ['es', 'ru-RU'])
    @account.add_feature(:multi_language)
    @account.features.enable_multilingual.create
    @account.reload
    additional = @account.account_additional_settings
    additional.supported_languages = supported_languages
    additional.save
  end

  def central_publish_article_tags_pattern(article)
    { added_tags: article.tag_changes[:added_tags], removed_tags: article.tag_changes[:removed_tags] }
  end

  def central_publish_category_destroy_pattern(item)
    {
      id: item.parent_id,
      category_id: item.id,
      language_code: item.language_code,
      account_id: item.account_id,
      name: item.name
    }
  end

  def central_publish_folder_destroy_pattern(item)
    {
      id: item.parent_id,
      folder_id: item.id,
      language_code: item.language_code,
      account_id: item.account_id,
      name: item.name
    }
  end

  def central_publish_article_destroy_pattern(article)
    {
      id: article.parent_id,
      article_id: article.id,
      account_id: article.account_id,
      language_code: article.language_code,
      title: article.title
    }
  end
end
