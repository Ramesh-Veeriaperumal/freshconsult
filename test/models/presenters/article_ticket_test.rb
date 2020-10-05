require_relative '../test_helper'
['archive_ticket_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }

class ArticleTicketTest < ActiveSupport::TestCase
  include TicketsTestHelper
  include ModelsSolutionsTestHelper
  include ArchiveTicketTestHelper

  def setup
    super
    $redis_others.perform_redis_op('set', 'ARTICLE_SPAM_REGEX', Faker::Lorem.word)
    $redis_others.perform_redis_op('set', 'PHONE_NUMBER_SPAM_REGEX', Faker::Lorem.word)
    $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', Faker::Lorem.word)
  end

  def test_central_publish_payload
    article = create_article(article_params).primary_article
    ticket = create_ticket
    CentralPublisher::Worker.jobs.clear
    article_ticket = add_article_ticket(article, ticket)
    job = CentralPublisher::Worker.jobs.last
    assert_equal 'article_ticket_create', job['args'][0]
    assert_equal 1, CentralPublisher::Worker.jobs.size
    payload = article_ticket.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_ticket_pattern(article_ticket))
    event_info = article_ticket.event_info(:create)
    event_info.must_match_json_expression(central_publish_article_ticket_event_info)
  end

  def test_central_publish_payload_archive_article_ticket
    @account.enable_ticket_archiving(120) unless @account.archive_tickets_enabled?
    article = create_article(article_params).primary_article
    ticket = create_ticket
    article_ticket = add_article_ticket(article, ticket)
    ticket.updated_at = 150.days.ago
    ticket.status = 5
    ticket.save!
    CentralPublisher::Worker.jobs.clear
    convert_ticket_to_archive(ticket)
    article_ticket.reload
    job = CentralPublisher::Worker.jobs.last
    assert_equal 1, CentralPublisher::Worker.jobs.size
    assert_equal 'article_ticket_update', job['args'][0]
    payload = article_ticket.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_ticket_pattern(article_ticket))
  end

  def test_central_publish_payload_for_article_ticket_destroy
    article = create_article(article_params).primary_article
    ticket = create_ticket
    article_ticket = add_article_ticket(article, ticket)
    CentralPublisher::Worker.jobs.clear
    ticket.destroy
    job = CentralPublisher::Worker.jobs.last
    assert_equal 1, CentralPublisher::Worker.jobs.size
    assert_equal 'article_ticket_destroy', job['args'][0]
    payload = article_ticket.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_ticket_pattern(article_ticket))
  end

  def article_params(options = {})
    lang_hash = { lang_codes: options[:lang_codes] }
    category = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
    {
      title: 'Test',
      description: 'Test',
      folder_id: create_folder({ visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id }.merge(lang_hash)).id,
      status: options[:status] || Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
    }.merge(lang_hash)
  end
end
