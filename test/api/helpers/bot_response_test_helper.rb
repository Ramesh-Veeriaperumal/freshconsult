['solutions_test_helper.rb', 'controller_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
['users_test_helper.rb' ,'attachments_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

module BotResponseTestHelper
  include TicketHelper
  include CoreSolutionsTestHelper
  include AttachmentsTestHelper
  include ControllerTestHelper
  include UsersTestHelper

  TYPE="FEEDBACK"
  PAYLOAD_TYPE="freshdesk-email-bot-feedback"

  def get_bot
    @account.portals.first.bot if @account.portals.any?
  end

  def construct_request_body bot_response, article_meta_id
    payload = construct_central_payload(bot_response,article_meta_id)
    {
      account_id: Account.current.id.to_s,
      payload_type: PAYLOAD_TYPE,
      payload: payload
    }.to_json
  end

  def construct_central_payload bot_response, article_meta_id
    {
      queryId: bot_response.query_id,
      ticketId: bot_response.ticket_id,
      queryDate: bot_response.created_at.to_i,
      portal_id: bot_response.bot.portal_id.to_s,
      type: TYPE,
      productId: BOT_CONFIG[:freshdesk_product_id],
      domainName: bot_response.bot.portal.host,
      query: bot_response.ticket.ticket_body.description,
      faqs: construct_faqs(bot_response),
    }
  end

  def construct_faqs bot_response
    bot_response.suggested_articles.each.map do |article_id, suggested_hash|
      {
        text: suggested_hash[:title],
        articleId: article_id,
        useful: suggested_hash[:useful],
        agent_useful: suggested_hash[:agent_feedback]
      }
    end
  end

  def create_sample_bot_response(ticket_id, bot_id, query_id, suggested_articles)
    ticket_id ||= create_ticket(requester_id: @agent.id).id
    query_id ||= Faker::Lorem.characters(20)
    params = {
      ticket_id: ticket_id,
      bot_id: bot_id,
      query_id: query_id,
      suggested_articles: suggested_articles
    }
    bot_response = @account.bot_responses.new(params)
    bot_response.save
    bot_response
  end

  def construct_suggested_articles
    suggested_articles = {}
    @@articles = []
    3.times.each do |time|
      article = create_article
      @@articles << article
      suggested_articles[article.id] = {
        title: article.title,
        opened: false
      }
    end
    suggested_articles
  end

  def support_namespace_bot_response_pattern(solution_id)
    item = @account.bot_responses.last
    useful = item.useful?(solution_id)
    response = {
      ticket_closed: item.ticket.closed?,
      positive_feedback: item.has_positive_feedback?
    }
    unless useful.nil?
      response[:useful] = useful
      response.merge!(construct_other_articles(solution_id,item)) unless useful
    end
    response
  end

  def construct_other_articles(solution_id,item)
    other_articles = item.solutions_without_feedback.each.map do |article_meta_id|
      article = @account.solution_article_meta.find(article_meta_id)
      { 
        url: article_url(article, item.bot),
        title: article.title
      }
    end
    other_articles.present? ? { other_articles: other_articles } : {}
  end

  def article_url article, bot
    support_solutions_article_url(article, :host => bot.portal.host)
  end

  def central_publish_bot_response_pattern(bot_response)
    {
      id: bot_response.id,
      account_id: bot_response.account_id,
      ticket_id: bot_response.ticket_id,
      bot_id: bot_response.bot_id,
      suggested_articles: cp_suggested_hash(bot_response.suggested_articles),
      query_id: bot_response.query_id,
      bot_external_id: bot_response.bot.external_id,
      created_at: bot_response.created_at.try(:utc).try(:iso8601),
      updated_at: bot_response.updated_at.try(:utc).try(:iso8601)

    }
  end

  def central_publish_bot_response_association_pattern(expected_output = {})
    {
      ticket: Hash
    }
  end

  def central_publish_bot_response_destroy_pattern(bot_response)
    {
      id: bot_response.id,
      ticket_id: bot_response.ticket_id,
      account_id: bot_response.account_id,
    }
  end

  def update_bot_response(bot_response)
    bot_response.assign_opened(bot_response.suggested_articles.first[0], true)
    bot_response.save
    bot_response.reload
  end

  def model_changes_for_central_pattern(bot_response)
    {
      "suggested_articles" => [
        {
          "id" => bot_response.suggested_articles.first[0],
          "attributes" => [{
            "name" => 'opened',
            "value" => [false, true]
          }]
        }
      ]
    }
  end

  def enable_bot_email_channel
    Account.current.stubs(:all_launched_features).returns([:bot_email_channel])
    yield
  ensure
    Account.current.unstub(:all_launched_features)
  end

  def enable_bot_agent_response
    Account.current.stubs(:bot_agent_response_enabled?).returns(true)
    yield
  ensure
    Account.current.unstub(:bot_agent_response_enabled?)
  end

  def create_bot_response(ticket_id = nil, bot_id = nil)
    ticket_id = ticket_id || Helpdesk::Ticket.first.try(:id)
    bot_id = bot_id || Bot.first.try(:id)
    Account.current.bot_responses.create(ticket_id: ticket_id, 
      bot_id: bot_id,
      query_id: UUIDTools::UUID.timestamp_create.hexdigest, 
      suggested_articles: suggested_articles_pattern)
  end

  def suggested_articles_pattern 
    { 
      Faker::Number.number(8).to_i => { 
        title: Faker::Lorem.characters(10),
        opened: nil,
        useful: nil},
      Faker::Number.number(8).to_i => {
        title: Faker::Lorem.characters(10),
        opened: nil,
        useful: nil },
      Faker::Number.number(8).to_i => {
        title: Faker::Lorem.characters(10),
        opened: nil,
        useful: nil }
    }
  end

  def bot_response_pattern(bot_response, params = nil)
    if params.present?
      params[:articles].each do |article|
        bot_response.suggested_articles[article[:id]] = bot_response.suggested_articles[article[:id]].merge(article.except(:id))
      end
    end
    bot_response.updated_at = Time.parse(Bot::Response.find(bot_response.id).updated_at.to_s).utc.iso8601
    bot_response.created_at = Time.parse(Bot::Response.find(bot_response.id).created_at.to_s).utc.iso8601
    response = Tickets::BotResponseDecorator.new(bot_response).to_hash
    response
  end

  def create_test_email_bot(options)
    portal_id = @account.main_portal.id || create_portal.id
    bot = FactoryGirl.build(:bot,
                            account_id: Account.current.id,
                            portal_id: portal_id,
                            last_updated_by: get_admin.id,
                            template_data: test_template_data,
                            enable_in_portal: true,
                            external_id: get_uuid,
                            additional_settings: {
                              bot_hash: get_uuid,
                              is_default: false
                            })
    bot.email_channel = options[:email_channel] || false
    bot.save
    bot
  end

  private

  def cp_suggested_hash(suggested_articles)
    articles = []
    suggested_articles.each do |article|
    articles.push({
      id: article.first,
      title: article.last[:title] ,
      opened: article.last[:opened],
      useful: article.last[:useful],
      agent_feedback: article.last[:agent_feedback]
    })
    end
    articles
  end

  def get_uuid
    UUIDTools::UUID.timestamp_create.hexdigest
  end

  def test_template_data
    test_template_data = {
      header: Faker::Lorem.sentence,
      theme_colour: '#039a7b',
      widget_size: 'STANDARD'
    }
  end
end