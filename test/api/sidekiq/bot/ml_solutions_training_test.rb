require_relative '../../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
require Rails.root.join('test', 'api', 'helpers', 'bot_test_helper.rb')
require Rails.root.join('test', 'core', 'helpers', 'controller_test_helper.rb')

class MlSolutionsTrainingTest < ActionView::TestCase
  include ApiBotTestHelper
  include SolutionsHelper
  include ControllerTestHelper
  include SolutionBuilderHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:switch_annual_notification_eligible?).returns(false)
    @account = Account.current
    @bot = @account.main_portal.bot || create_bot({default_avatar: 1})
    @agent = get_admin()
    setup_solutions
  end

  def teardown
    Account.unstub(:current)
    Subscription.any_instance.unstub(:switch_annual_notification_eligible?)
    super
  end

  def setup_solutions
    subscription = @account.subscription
    subscription.state = 'active'
    subscription.save
    @account.reload
    create_article(article_params)
    create_article(article_params(Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]))
  end

  def test_ml_solutions_training
    payloads_count = central_payloads_count
    stub_method_count = 0
    CentralPublisher.configuration.central_connection.stub :post, -> { stub_method_count+=1; Faraday::Response.new(status: 202, body: {}) } do
      Bot::MlSolutionsTraining.new.perform(bot_id: @bot.id)
    end
    assert_equal payloads_count, stub_method_count
  ensure
    CentralPublisher.configuration.central_connection.unstub(:post)
  end

  def test_ml_solutions_training_with_401_from_central
    assert_nothing_raised do
      CentralPublisher.configuration.central_connection.stub :post, -> { Faraday::Response.new(status: 401, body: {}) } do
        Bot::MlSolutionsTraining.new.perform(bot_id: @bot.id)
      end
    end
  ensure
    CentralPublisher.configuration.central_connection.unstub(:post)
  end

  def test_ml_solutions_training_with_exception_handled
    assert_nothing_raised do
      Solution::CategoryMeta.any_instance.stubs(:primary_category).raises(RuntimeError)
      CentralPublisher.configuration.central_connection.stub :post, -> { Faraday::Response.new(status: 202, body: {}) } do
        Bot::MlSolutionsTraining.new.perform(bot_id: @bot.id)
      end
    end
  ensure
    Solution::CategoryMeta.any_instance.unstub(:primary_category)
    CentralPublisher.configuration.central_connection.unstub(:post)
  end

  # Private method tests
  # Testing request_body function seperately as CentralPublisher.configuration.central_connection is stubbed in above tests
  def test_request_body
    ml_solutions_training_object = Bot::MlSolutionsTraining.new
    request_payload = ml_solutions_training_object.safe_send(:request_body, @bot, :ml_training_start)
    request_payload.must_match_json_expression(request_body_ml_training_start_pattern(@bot))
  end

  private

    def central_payloads_count
      count = 2 # Including ml_training_start and ml_training_end
      @portal = Account.current.portals.where(id: @bot.portal_id).first
      portal_categories.each do |category_meta|
        next if category_meta.is_default?
        count+=1
        category_meta.solution_folder_meta.each do |folder_meta|
          count+=1
          folder_meta.solution_article_meta.each do |article_meta|
            primary_article = article_meta.primary_article
            next unless primary_article.status == Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
            count+=1
          end
        end
      end
      count
    end

    def portal_categories
      @portal.solution_category_meta.includes([:primary_category, { portals: :portal_solution_categories }, { solution_folder_meta: [ :primary_folder, { solution_article_meta: [ { primary_article: [ :article_body, :attachments, :tags ] }, :solution_category_meta ] } ]}])
    end

    def article_params(status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published], folder_visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
      category = create_category
      {
        title: "Test",
        description: "Test",
        folder_id: create_folder(visibility: folder_visibility, category_id: category.id).id,
        status: status
      }
    end
end