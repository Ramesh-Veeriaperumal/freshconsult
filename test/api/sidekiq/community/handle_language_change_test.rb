require_relative '../../unit_test_helper'
require 'sidekiq/testing'
require 'minitest/autorun'
require Rails.root.join('test', 'models', 'helpers', 'solutions_test_helper.rb')

Sidekiq::Testing.fake!

class HandleLanguageChangeTest < ActionView::TestCase

  include ModelsSolutionsTestHelper

  def setup
    $redis_others.perform_redis_op('set', 'ARTICLE_SPAM_REGEX', '(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)')
    $redis_others.perform_redis_op('set', 'PHONE_NUMBER_SPAM_REGEX', '(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436')
    $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', 'ℴ|ℕ|ℓ|ℳ|ℱ|ℋ|ℝ|ⅈ|ℯ|ℂ|○|ℬ|ℂ|ℙ|ℹ|ℒ|ⅉ|ℐ|ℰ|ℭ|ℍ|𝒾|ℛ')
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