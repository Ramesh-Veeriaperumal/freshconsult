require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'webmock/minitest'
WebMock.allow_net_connect!
Sidekiq::Testing.fake!
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'create_ticket_helper.rb')
require Rails.root.join('test', 'api', 'helpers', 'bot_response_test_helper.rb')


class SendBotEmailTest < ActionView::TestCase
  include SolutionsHelper
  include ControllerTestHelper
  include SolutionBuilderHelper
  include CreateTicketHelper
  include BotResponseTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def create_ticket
    create_test_ticket(ticket_params)
  end

  def ticket_params
    {
      email: 'sample@freshdesk.com', 
      source: Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:email]
    }
  end

  def fetch_bot_and_articles
    @bot = @account.main_portal.bot || create_test_email_bot({email_channel: true})
    @articles = get_articles
  end

  def get_articles
    @agent = get_admin()
    setup_solutions
    @articles = []
    3.times do
      @articles.push(create_article(article_params))
    end
    @articles
  end

  def setup_solutions
    subscription = @account.subscription
    subscription.state = 'active'
    subscription.save
    @account.reload
  end

  def test_send_bot_email
    delayed_job_size_before = Delayed::Job.count
    ticket = create_ticket
    fetch_bot_and_articles
    stub_request(:post, %r{^https://freshiqnew.freshpo.com/api/v1/afr/smart_reply.*?$}).to_return(body: stub_response(true).to_json, status: 200)
    ::Bot::Emailbot::SendBotEmail.new.perform(ticket_id: ticket.id)
    delayed_job_size_after = Delayed::Job.count
    assert_equal delayed_job_size_before + 1, delayed_job_size_after 
  end

  def test_send_bot_email_with_invalid_response
    delayed_job_size_before = Delayed::Job.count
    ticket = create_ticket
    fetch_bot_and_articles
    stub_request(:post, %r{^https://freshiqnew.freshpo.com/api/v1/afr/smart_reply.*?$}).to_return(body: invalid_response.to_json, status: 200)
    ::Bot::Emailbot::SendBotEmail.new.perform(ticket_id: ticket.id)
    delayed_job_size_after = Delayed::Job.count
    assert_equal delayed_job_size_before, delayed_job_size_after
  end

  def test_send_bot_email_with_null_response
    delayed_job_size_before = Delayed::Job.count
    ticket = create_ticket
    fetch_bot_and_articles
    stub_request(:post, %r{^https://freshiqnew.freshpo.com/api/v1/afr/smart_reply.*?$}).to_return(body: stub_response(false).to_json, status: 200)
    ::Bot::Emailbot::SendBotEmail.new.perform(ticket_id: ticket.id)
    delayed_job_size_after = Delayed::Job.count
    assert_equal delayed_job_size_before, delayed_job_size_after
  end

  def test_send_bot_email_to_raise_exception
    delayed_job_size_before = Delayed::Job.count
    ticket = create_ticket
    fetch_bot_and_articles
    stub_request(:post, %r{^https://freshiqnew.freshpo.com/api/v1/afr/smart_reply.*?$}).to_timeout
    ::Bot::Emailbot::SendBotEmail.new.perform(ticket_id: ticket.id)
    delayed_job_size_after = Delayed::Job.count
    assert_equal delayed_job_size_before, delayed_job_size_after
  end

  def test_notify_by_email
    ticket = create_ticket
    mail_message = Helpdesk::TicketNotifier.notify_by_email(EmailNotification::BOT_RESPONSE_TEMPLATE, ticket, nil, {freddy_suggestions: "test"})
    assert_equal ticket.from_email, mail_message.to.first
    assert_equal "Re: #{ticket.subject}", mail_message.subject
  end

  private

    def article_params(status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published], folder_visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
      category = create_category
      {
        title: "Test",
        description: Faker::Lorem.paragraph,
        folder_id: create_folder(visibility: folder_visibility, category_id: category.id).id,
        status: status
      }
    end

    def data_hash(empty_response)
      data = []
      if empty_response
        @articles.each do |article|
          hash = 
          {
                    "score": 1.0000000000000004,
                    "detail_html": "You can associate 300 tickets to a single Tracker.",
                    "title": "#{article.title}",
                    "url": nil,
                    "title_nouns": "['ticket']",
                    "detail": "You can associate 300 tickets to a single Tracker.",
                    "visibility": "5",
                    "title_adjectives": "[]",
                    "adjectives": "['singl']",
                    "verbs": "['link', 'limit', 'associ']",
                    "folder_id": "#{article.folder_id}",
                    "nouns": "['ticket', 'ticket', 'tracker']",
                    "title_verbs": "['link', 'limit']",
                    "category_id": "161458",
                    "type": "kb",
                    "id": "#{article.id}"
          }
          data.push(hash)
        end
      end
      data
    end

    def stub_response(empty_response)
      {
        "result": 
          {
            "msg": "Call Successful",
            "data": data_hash(empty_response),
            "show_result": empty_response,
            "pos_model_score": 0.47530055433187057,
            "success": empty_response
        }
      }
    end

    def invalid_response
      data = []
      3.times do
        hash = 
          {
                    "score": 1.0000000000000004,
                    "detail_html": "You can associate 300 tickets to a single Tracker.",
                    "title": "#test",
                    "url": nil,
                    "title_nouns": "['ticket']",
                    "detail": "You can associate 300 tickets to a single Tracker.",
                    "visibility": "5",
                    "title_adjectives": "[]",
                    "adjectives": "['singl']",
                    "verbs": "['link', 'limit', 'associ']",
                    "folder_id": "1",
                    "nouns": "['ticket', 'ticket', 'tracker']",
                    "title_verbs": "['link', 'limit']",
                    "category_id": "161458",
                    "type": "kb",
                    "id": "21324238"
          }
          data.push(hash)
      end
        {
          "result": 
            {
              "msg": "Call Successful",
              "data": data,
              "show_result": true,
              "pos_model_score": 0.47530055433187057,
              "success": true
          }
        }
    end
end