module BotTestHelper
  include UsersTestHelper
  include CompanyTestHelper
  include TicketsTestHelper

  def create_bot(options = {})
    avatar_hash = {
      is_default: false
    }
    if options[:default_avatar]
      avatar_hash = {
        is_default: true,
        avatar_id: Faker::Number.number(10),
        default_avatar_url: Faker::Avatar.image        
      }
    else
      attachment = create_attachment
    end
    test_template_data = {
      header: Faker::Lorem.sentence,
      theme_colour: '#039a7b',
      widget_size: 'STANDARD'
    }

    if options[:product]
      test_product = create_product(portal_url: Faker::Avatar.image)
      portal_id = test_product.portal.id
      product_id = test_product.id
    else
      test_portal = @account.main_portal
      portal_id = test_portal.id
    end
    test_bot = FactoryGirl.build(:bot,
                                 name: options[:bot_name] || Faker::Name.name,
                                 account_id: @account.id,
                                 portal_id: portal_id,
                                 product_id: product_id,
                                 template_data: options[:template_data] || test_template_data,
                                 enable_in_portal: options[:enable_in_portal] || [true, false].sample,
                                 external_id: generate_uuid,
                                 additional_settings: {
                                   bot_hash: generate_uuid
                                 }.merge(avatar_hash),
                                 last_updated_by: options[:last_updated_by] || 1)
    test_bot.logo = attachment
    test_bot.save(validate: false)
    test_bot.training_not_started!
    test_bot
  end

  def generate_uuid
    UUIDTools::UUID.timestamp_create.hexdigest
  end

  def bot_index_not_onboarded_main_portal_pattern
    offboard_bot
    main_portal_index_pattern
  end

  def bot_index_not_onboarded_multiproduct_pattern
    offboard_bot
    product_list_pattern
  end

  def bot_index_onboarded_multiproduct_pattern
    onboard_bot
    product_list_pattern
  end

  def bot_index_onboarded_main_portal_pattern
    onboard_bot
    main_portal_index_pattern
  end

  def bot_new_pattern(portal)
    new_hash = {
      product: product_hash(portal),
      all_categories: categories_list_pattern(portal)
    }
    new_hash = new_hash.merge(joehukum_default_profile)
    new_hash
  end

  def joehukum_default_profile(params = {})
    profile = {
      theme_colour: params['bgcolor'] || '#039a7b',
      widget_size: params['widget_size'] || 'STANDARD'
    }
    profile
  end

  def product_hash(portal)
    name = portal.main_portal? ? portal.name : portal.product.name
    {
      name: name,
      portal_id: portal.id,
      portal_logo: get_portal_logo_url(portal)
    }
  end

  def enable_multiple_user_companies
    !Account.current.multiple_user_companies_enabled? && Account.current.add_feature(:multiple_user_companies)
  end

  def enable_bot
    Account.current.add_feature(:support_bot)
    yield
  ensure
    disable_bot
  end

  def disable_bot
    Account.current.revoke_feature(:support_bot)
  end

  def offboard_bot
    @bots = {}
    @bots[:onboarded] = false
    @bots
  end

  def onboard_bot
    @bots = {}
    @bots[:onboarded] = true
    @bots
  end

  def main_portal_index_pattern
    products_details = []
    products_details << main_portal_bot_info
    @bots[:products] = products_details
    [@bots]
  end

  def main_portal_bot_info
    main_portal = @account.main_portal
    logo_url = get_portal_logo_url main_portal
    bot = main_portal.bot
    bot_name, bot_id = [bot.name, bot.id] if bot
    { name: main_portal.name, portal_enabled: true, portal_id: main_portal.id, portal_logo: logo_url, bot_name: bot_name, bot_id: bot_id }
  end

  def show_pattern(bot)
    default = default_avatar? bot
    avatar_id = bot.additional_settings[:is_default] if default
    template_data = bot.template_data
    portal = bot.portal
    avatar_hash = {
      url: thumbnail_cdn_url(bot),
      avatar_id: avatar_id,
      is_default: default

    }
    show_pattern = {
      id: bot.id,
      status: '1',
      name: bot.name,
      avatar: avatar_hash,
      header: template_data[:header],
      theme_colour: template_data[:theme_colour],
      widget_size: template_data[:widget_size],
      product: product_hash(portal),
      external_id: bot.external_id,
      enable_on_portal: bot.enable_in_portal,
      all_categories: categories_list_pattern(portal),
      selected_category_ids: bot.solution_category_metum_ids,
      widget_code_src: BOT_CONFIG[:widget_code_src],
      product_hash: BOT_CONFIG[:freshdesk_product_id],
      environment: BOT_CONFIG[:widget_code_env]
    }
    show_pattern[:analytics_mock_data] = true if bot.additional_settings[:analytics_mock_data]
    show_pattern
  end

  def thumbnail_cdn_url(bot)
    return if default_avatar?(bot)
    thumb_cdn_url = bot.logo.content.url(:thumb).gsub(BOT_CONFIG[:avatar_bucket_url], BOT_CONFIG[:avatar_cdn_url]) if bot.logo && bot.logo.content
    thumb_cdn_url
  end

  def default_avatar?(bot)
    bot.additional_settings.present? && bot.additional_settings[:is_default]
  end

  def get_portal_logo_url(portal)
    logo = portal.logo
    logo_url = logo.content.url if logo
    logo_url
  end

  def bot_default_data
    {
      bot_name: 'Frank',
      avatar:   'https://s3.amazonaws.com/cdn.freshpo.com',
      theme_colour: '#039a7b',
      widget_size: 'STANDARD',
      widget_position: 30
    }
  end

  def product_list_pattern
    products_details = []
    products_details << main_portal_bot_info
    products = @account.products.preload({ portal: :logo }, :bot)
    products.each do |product|
      portal = product.portal
      products_details << if portal
                            logo_url = get_portal_logo_url portal
                            bot = portal.bot
                            bot_name, bot_id = [bot.name, bot.id] if bot
                            { name: product.name, portal_enabled: true, portal_id: portal.id, portal_logo: logo_url, bot_name: bot_name, bot_id: bot_id }
                          else
                            { name: product.name, portal_enabled: false }
                          end
    end

    @bots[:products] = products_details
    [@bots]
  end

  def assert_bot_failure(pattern)
    assert_response 400
    match_json([bad_request_error_pattern(*pattern)]) if pattern.present?
  end

  def bot_create_pattern(bot_id)
    {
      id: bot_id
    }
  end

  def create_bot_feedback(bot_id, params = {})
    bot_feedback = FactoryGirl.build(:bot_feedback,
                            account_id: Account.current.id,
                            bot_id: bot_id,
                            category: params[:category] || BotFeedbackConstants::FEEDBACK_CATEGORY_KEYS_BY_TOKEN[:unanswered],
                            useful: params[:useful] || BotFeedbackConstants::FEEDBACK_USEFUL_KEYS_BY_TOKEN[:default],
                            received_at: DateTime.now.utc,
                            query_id: UUIDTools::UUID.timestamp_create.hexdigest,
                            query: Faker::Lorem.sentence,
                            external_info: { chat_id: UUIDTools::UUID.timestamp_create.hexdigest, customer_id: UUIDTools::UUID.timestamp_create.hexdigest, client_id: UUIDTools::UUID.timestamp_create.hexdigest},
                            state: params[:state] || BotFeedbackConstants::FEEDBACK_STATE_KEYS_BY_TOKEN[:default])
    bot_feedback.save
    bot_feedback
  end

  def create_bot_feedback_and_bot_ticket(helpdesk_ticket,bot)
    bot_feedback = create_bot_feedback(@bot.id)
    bot_ticket = helpdesk_ticket.build_bot_ticket(ticket_id: helpdesk_ticket.id, account_id: Account.current.id, bot_id: bot.id, query_id: bot_feedback.query_id, conversation_id: bot_feedback.query_id)
    bot_ticket.save
    bot_feedback
  end


  def create_ticket_with_requester_and_companies
    company_ids = [create_company, create_company].map(&:id)
    requester = create_contact_with_other_companies(@account, company_ids)
    create_ticket(:requester_id => requester.id)
  end

  def bot_feedback_index_pattern(bot, start_at, end_at, useful = 1)
    useful = useful.present? ? [useful] : [1,3]
    conditions  = { bot_id: bot.id, state: 1, category: 2, useful: useful, created_at: start_at..end_at }
    unanswered_list = bot.bot_feedbacks.where(conditions).preload(ticket: { requester: [ { user_companies: { company: :avatar } }, :avatar] }).order('received_at DESC')
    responses = unanswered_list.map do |item|
      response_hash = {
        id: item.id,
        bot_id: item.bot_id,
        category: item.category,
        useful: item.useful,
        received_at: item.received_at,
        query_id: item.query_id,
        query: item.query,
        state: item.state,
        chat_id: item.chat_id,
        customer_id: item.customer_id,
        client_id: item.client_id
      }
      if item.ticket
        response_hash[:ticket_id] = item.ticket.display_id
        response_hash[:requester] = contact_hash(item.ticket.requester, :sideload_options => ['company'])
      end
      response_hash
    end
    responses
  end

  def contact_hash(contact, options)
    contact_hash = {
      id: contact.id,
      name: contact.name,
      job_title: contact.job_title,
      email: contact.email,
      phone: contact.phone,
      mobile: contact.mobile,
      twitter_id: contact.twitter_id,
      has_email: contact.email.present?,
      active: contact.active,
      avatar: contact.avatar
    }
    contact_hash.merge(company_info(contact)) if options[:sideload_options] && options[:sideload_options].include?('company')
  end

  def company_info(contact)
    ret_hash = {}
    if contact.default_user_company.present?
      ret_hash[:company] = company_hash(contact)
      ret_hash[:other_companies] = other_companies_hash(true, contact) if @account.multiple_user_companies_enabled?
    end
    ret_hash
  end

  def create_params(portal)
    {
      version: 'private',
      format: :json,
      name: 'freshdeskbot',
      portal_id: portal.id,
      header: 'This is the header of the chat box',
      theme_colour: '#039a7b',
      widget_size: 'STANDARD'
    }
  end

  def categories_list_pattern(portal)
    Language.for_current_account.make_current
    public_category_meta = portal.public_category_meta
    articles_count = Solution::CategoryMeta.bot_articles_count_hash(public_category_meta.map(&:id))
    Language.reset_current
    public_category_meta.map do |category|
      { id: category.id, label: category.name, articles_count: articles_count[category.id] || 0 }
    end
  end

  def create_n_bot_feedbacks(bot_id, count, params = {})
    bot_feedback_ids = []
    count.times do
      bot_feedback_ids << create_bot_feedback(bot_id, params).id
    end
    bot_feedback_ids
  end

  def create_bot_feedback_and_bot_ticket(helpdesk_ticket,bot)
    bot_feedback = create_bot_feedback(bot.id)
    bot_ticket = helpdesk_ticket.build_bot_ticket(ticket_id: helpdesk_ticket.id, account_id: Account.current.id, bot_id: bot.id, query_id: bot_feedback.query_id, conversation_id: bot_feedback.query_id)
    bot_ticket.save
    bot_feedback
  end

  def article_params(folder_visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
    category = create_category
    {
      title: "Test",
      description: "Test",
      folder_id: create_folder(visibility: folder_visibility, category_id: category.id).id
    }
  end

  def invalid_article_params
    {
      title: 999,
      description: 999,
      folder_id: "Test"
    }
  end

  def bot_analytics_hash
    {
      content: {
        stats: [
          {
            date: '2018-02-02',
            vls: {
              total_questions: 10,
              not_helpful: 4,
              attempted: 8,
              initiated_chats: 3
            }
          }
        ]
      }
    }.to_json
  end

  def analytics_response_pattern
    [
      {
        date: '2018-02-01',
        vls: BotConstants::DEFAULT_ANALYTICS_HASH
      },
      {
        date: '2018-02-02',
        vls: {
          total_questions: 10,
          not_helpful: 4,
          attempted: 8,
          helpful: 0,
          not_attempted: 0,
          initiated_chats: 3
        }
      }
    ].to_json
  end

  def request_body_ml_training_start_pattern(bot)
    {
      account_id: Account.current.id.to_s,
      payload_type: 'ml_training_start',
      payload: {
        account_full_domain: Account.current.full_domain,
        model_properties: central_publish_ml_training_start_pattern(bot)
      }
    }
  end

  def central_publish_ml_training_start_pattern(bot)
    {
      external_id: bot.external_id,
      category_ids: bot.solution_category_metum_ids,
      account_id: bot.account_id
    }
  end
end
