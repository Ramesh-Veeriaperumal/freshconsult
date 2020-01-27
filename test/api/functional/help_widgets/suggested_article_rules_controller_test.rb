require_relative '../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')

class HelpWidgets::SuggestedArticleRulesControllerTest < ActionController::TestCase
  include HelpWidgetsTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.make_current
    @account.stubs(:help_widget_enabled?).returns(true)
    @account.launch(:help_widget_article_customisation)
  end

  def tear_down
    @account.unstub(:help_widget_enabled?)
    @account.rollback(:help_widget_article_customisation)
  end

  def create_widget_suggested_article_rules(conditions: {}, rule_operator: 1, filter: {}, position: 1)
    widget = create_widget(solution_articles: true)
    widget.help_widget_suggested_article_rules.build(conditions: conditions,
                                                     rule_operator: rule_operator,
                                                     filter: filter,
                                                     position: position)
    widget.save!
    widget
  end

  def test_index_suggested_article_rules
    conditions = [{ evaluate_on: 'page', name: 'url', operator: 1, value: 'refund' }]
    filter = { type: 1, value: [1, 3, 4], order_by: 'hits' }
    help_widget = create_widget_suggested_article_rules(conditions: conditions, filter: filter)
    get :index, controller_params(version: 'private', help_widget_id: help_widget.id)
    assert_response 200
    match_json(suggested_article_rules_index_pattern(help_widget))
  ensure
    help_widget.destroy
  end

  def test_index_without_help_widget_article_customisation_feature
    @account.rollback(:help_widget_article_customisation)
    widget = create_widget(solution_articles: true)
    get :index, controller_params(version: 'private', help_widget_id: widget.id)
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The help_widget, help_widget_article_customisation feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    @account.launch(:help_widget_article_customisation)
    widget.destroy
  end

  def test_index_without_help_widget_enabled
    @account.stubs(:help_widget_enabled?).returns(false)
    widget = create_widget(olution_articles: true)
    get :index, controller_params(version: 'private', help_widget_id: widget.id)
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The help_widget, help_widget_article_customisation feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    @account.unstub(:help_widget_enabled?)
    widget.destroy
  end

  def test_index_with_invalid_help_widget_id
    get :index, controller_params(version: 'private', help_widget_id: 'id')
    assert_response 400
    match_json('description' => 'Validation failed',
               'errors' => [bad_request_error_pattern('help_widget_id', 'It should be a/an Positive Integer', code: 'datatype_mismatch')])
  end

  def test_index_with_help_widget_id_absent
    get :index, controller_params(version: 'private', help_widget_id: 900_090)
    assert_response 400
    match_json('code' => 'invalid_help_widget',
               'message' => 'invalid_help_widget')
  end
end
