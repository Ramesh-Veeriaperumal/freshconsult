# frozen_string_literal: true

require_relative '../../../../api/api_test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb', 'user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['search_test_helper.rb', 'privileges_helper.rb', 'test_class_methods.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
class Support::SearchV2::SolutionsControllerFlowTest < ActionDispatch::IntegrationTest
  include SolutionsHelper
  include SolutionBuilderHelper
  include SearchTestHelper
  include PrivilegesHelper
  include UsersHelper
  include TestClassMethods

  def test_related_articles_with_results
    set_redis_keys
    user = add_new_user(@account, active: true)
    article_meta = create_article(article_params.merge(user_id: user.id))
    article = article_meta.primary_article
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:enable_multilingual).returns(false)
    set_request_auth_headers(user)
    stub_private_search_response([article]) do
      account_wrap(user) do
        get "/support/search/articles/#{article_meta.id}/related_articles", version: :private, container: 'related_articles', limit: 5, url_locale: article.language
      end
    end
    assert_response 200
    assert response.body.include?(article.title)
  ensure
    Account.any_instance.unstub(:features?)
    article.destroy
    article_meta.destroy
    user.destroy
  end

  private

    def article_params(folder_visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
      category = create_category
      {
        title: 'Test',
        description: 'Test',
        folder_id: create_folder(visibility: folder_visibility, category_id: category.id).id
      }
    end

    def old_ui?
      true
    end

    def set_redis_keys
      $redis_others.perform_redis_op('set', 'ARTICLE_SPAM_REGEX', '(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)')
      $redis_others.perform_redis_op('set', 'PHONE_NUMBER_SPAM_REGEX', '(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436')
      $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', 'ℴ|ℕ|ℓ|ℳ|ℱ|ℋ|ℝ|ⅈ|ℯ|ℂ|○|ℬ|ℂ|ℙ|ℹ|ℒ|ⅉ|ℐ')
    end
end
