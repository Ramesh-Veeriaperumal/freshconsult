require_relative '../unit_test_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['account_test_helper.rb', 'controller_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }

class PrimaryLanguageChangeTest < ActionView::TestCase
  include AccountTestHelper
  include SolutionsHelper
  include SolutionBuilderHelper
  include ControllerTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    Subscription.any_instance.stubs(:switch_annual_notification_eligible?).returns(false)
    @account = Account.current
    subscription = @account.subscription
    subscription.state = 'active'
    subscription.save
    @account.reload
    @agent = get_admin()
    @article = create_article(article_params)
  end

  def teardown
    Account.unstub(:current)
    Subscription.any_instance.unstub(:switch_annual_notification_eligible?)
    super
  end

  def test_primary_language_change
    ::Admin::LanguageMailer.stubs(:deliver_primary_language_change).returns(nil)
    language = Language.all.reject { |l| l.code == Account.current.language }.sample
    PrimaryLanguageChange.new.perform(language: language.code, email: 'sample@freshdesk.com', language_name: language.name)
    ::Admin::LanguageMailer.unstub(:deliver_primary_language_change)
    assert_equal '200', response.code
    @category.reload
    @folder.reload
    @article.reload
    assert_equal language.code, @account.language
    assert_equal language.id, @category.primary_category.language_id
    assert_equal language.id, @folder.primary_folder.language_id
    assert_equal language.id, @article.primary_article.language_id
  end

  def test_primary_language_change_with_exception_handled
    assert_nothing_raised do
      user = create_dummy_customer
      @controller.stubs(:delete_secondary_translations).raises(RuntimeError)
      PrimaryLanguageChange.new.perform({})
    end
  ensure
    @controller.unstub(:delete_secondary_translations)
  end

  private

    def article_params(status = Solution::Article::STATUS_KEYS_BY_TOKEN[:published], folder_visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
      @category = create_category
      @folder = create_folder(visibility: folder_visibility, category_id: @category.id)
      {
        title: "Test",
        description: "Test",
        folder_id: @folder.id,
        status: status
      }
    end
end