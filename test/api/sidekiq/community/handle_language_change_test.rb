require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
require Rails.root.join('test', 'models', 'helpers', 'solutions_test_helper.rb')

Sidekiq::Testing.fake!

class HandleLanguageChangeTest < ActionView::TestCase

  include SolutionsTestHelper

  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
    @agent = @account.agents.first
    add_new_article
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_handle_language_change_worker
    Account.any_instance.stubs(:features_included?).with(:enable_multilingual).returns(false)
    Portal.any_instance.stubs(:language).returns('ar')
    Community::HandleLanguageChange.new.perform
    Community::HandleLanguageChange::SOLUTION_CLASSES.each { |klass|
      assert_not_equal klass.constantize.count,0
      assert_equal get_other_language_count(klass, 'ar'), 0
    }
    Portal.any_instance.stubs(:language).returns('en')
    Community::HandleLanguageChange.new.perform
    Community::HandleLanguageChange::SOLUTION_CLASSES.each { |klass|
      assert_equal get_other_language_count(klass, 'en'), 0
    }
  ensure
    Account.any_instance.unstub(:features_included?)
    Portal.any_instance.unstub(:language)
  end


  private

  def get_other_language_count(klass, language)
    klass.constantize.where('language_id != ?', Language.find_by_code(language).id).size
  end
end