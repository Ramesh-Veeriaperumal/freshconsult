# frozen_string_literal: true

require_relative '../../../../../test/api/api_test_helper'
['solutions_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['solutions_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
require Rails.root.join('test', 'models', 'helpers', 'solutions_test_helper.rb')

class Support::SolutionsFlowTest < ActionDispatch::IntegrationTest
  include SolutionsHelper
  include CoreSolutionsTestHelper
  include ModelsSolutionsTestHelper

  def test_index
    term = 'test'
    get "support/solutions/#{term}", portal_type: 'facebook'
    assert_response 302
    assert_redirected_to "/support/solutions/#{term}"
  end

  def test_index_route
    Account.any_instance.stubs(:multilingual?).returns(false)
    get 'support/solutions'
    assert_response 200
    assert_template 'support/solutions'
    assert_equal '/a/solutions', assigns[:agent_actions][0][:url]
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_particular_solution_not_found
    Account.any_instance.stubs(:multilingual?).returns(false)
    new_id = @account.solution_category_meta.length + 1
    get "support/solutions/#{new_id}"
    assert_response 404
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  def test_particular_solution_not_found_when_multilingual_is_enabled
    @account.add_feature(:multi_language)
    Account.any_instance.stubs(:multilingual?).returns(true)
    new_id = @account.solution_category_meta.length + 1
    account_language = @account.language
    get "#{account_language}/support/solutions/#{new_id}"
    assert_response 404
  ensure
    Account.any_instance.unstub(:multilingual?)
    @account.remove_feature(:multi_language)
  end

  def test_particular_solution_not_found_when_multilingual_is_enabled_and_facebook_portal
    @account.add_feature(:multi_language)
    Account.any_instance.stubs(:multilingual?).returns(true)
    new_id = @account.solution_category_meta.length + 1
    account_language = @account.language
    get "#{account_language}/support/solutions/#{new_id}", portal_type: 'facebook'
    assert_response 404
  ensure
    Account.any_instance.unstub(:multilingual?)
    @account.remove_feature(:multi_language)
  end

  def test_should_render_particular_category
    Account.any_instance.stubs(:multilingual?).returns(false)
    new_category = create_category
    get "/support/solutions/#{new_category.id}"
    @account.make_current
    assert_response 200
    assert_equal assigns[:category], new_category
    assert_equal assigns[:solution_item], new_category
    assigns[:page_meta].to_json.must_match_json_expression(compare_page_meta(new_category))
    assert_equal "/a/solutions/categories/#{new_category.id}", assigns[:agent_actions][0][:url]
  ensure
    new_category.destroy
    Account.any_instance.unstub(:multilingual?)
  end

  def test_should_render_particular_category_in_unscoped_fetch
    @account.add_feature(:multi_language)
    Account.any_instance.stubs(:multilingual?).returns(true)
    new_portal = create_portal
    new_category = create_category(name: "#{Faker::Lorem.sentence(2)} .ok", description: "#{Faker::Lorem.sentence(3)}ok", is_default: false, portal_ids: [new_portal.id])
    account_language = @account.language
    get "/#{account_language}/support/solutions/#{new_category.id}"
    @account.make_current
    assert_response 302
    assert_redirected_to "/#{account_language}/support/home"
  ensure
    Account.any_instance.unstub(:multilingual?)
    @account.remove_feature(:multi_language)
  end

  def test_render_with_default_category
    Account.any_instance.stubs(:multilingual?).returns(false)
    new_category = get_default_category
    get "support/solutions/#{new_category.id}"
    assert_response 404
  ensure
    Account.any_instance.unstub(:multilingual?)
  end

  private

    def get_default_category
      default_category = @account.solution_category_meta.where(is_default: true).first
      return create_category(is_default: true) if default_category.nil?

      default_category
    end

    def compare_page_meta(category)
      new_category = Solution::Category.find(category.id)
      res_hash = {
        title: new_category.name,
        description: new_category.description,
        canonical: String,
        image_url: String
      }
      res_hash
    end

    def old_ui?
      true
    end
end
