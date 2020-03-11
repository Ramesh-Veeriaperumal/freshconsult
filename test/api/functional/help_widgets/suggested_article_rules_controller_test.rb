require_relative '../../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
require Rails.root.join('spec', 'support', 'solution_builder_helper.rb')
require Rails.root.join('spec', 'support', 'solutions_helper.rb')

class HelpWidgets::SuggestedArticleRulesControllerTest < ActionController::TestCase
  include HelpWidgetsTestHelper
  include SolutionsHelper
  include SolutionBuilderHelper
  include AccountTestHelper

  def setup
    super
    before_all
  end

  def before_all
    @account = Account.first.make_current
    @account.stubs(:help_widget_enabled?).returns(true)
    @account.stubs(:help_widget_article_customisation_enabled?).returns(true)
    subscription = @account.subscription
    @old_subscription_state = subscription.state
    subscription.state = 'active'
    subscription.save
    @widget = create_widget(solution_articles: true)
    create_article_for_widget
  end

  def tear_down
    subscription = @account.subscription
    subscription.state = @old_subscription_state
    subscription.save
    @widget.destroy
    @account.unstub(:help_widget_enabled?)
    @account.unstub(:help_widget_article_customisation_enabled?)
    super
  end

  def create_article_for_widget
    category = create_category
    @widget.build_help_widget_solution_categories([category.id])
    @widget.save!
    folder = create_folder(category_meta_id: category.id)
    create_article(article_params(folder))
  end

  def article_params(folder)
    {
      title: 'Help Widget',
      description: 'Suggested Article Rules',
      status: 2,
      folder_id: folder.id
    }
  end

  def suggested_article_rule_request_params(params = {})
    {
      version: 'private',
      help_widget_id: @widget.id,
      suggested_article_rule: suggested_article_rule(params)
    }
  end

  def suggested_article_ids
    Account.current.solution_article_meta
           .for_help_widget(@widget, User.current)
           .published.limit(5)
           .pluck(:id)
  end

  def test_index_suggested_article_rules
    create_widget_suggested_article_rules(suggested_article_rule)
    get :index, controller_params(version: 'private', help_widget_id: @widget.id)
    assert_response 200
    match_json(suggested_article_rules_index_pattern(@widget))
  end

  def test_index_without_help_widget_article_customisation_feature
    @account.stubs(:help_widget_article_customisation_enabled?).returns(false)
    get :index, controller_params(version: 'private', help_widget_id: @widget.id)
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The help_widget, help_widget_article_customisation feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    @account.unstub(:help_widget_article_customisation_enabled?)
  end

  def test_index_without_help_widget_enabled
    @account.stubs(:help_widget_enabled?).returns(false)
    get :index, controller_params(version: 'private', help_widget_id: @widget.id)
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The help_widget, help_widget_article_customisation feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    @account.unstub(:help_widget_enabled?)
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

  def test_create_suggested_article_rules
    post :create, construct_params(suggested_article_rule_request_params)
    assert_response 201
    res = JSON.parse(@response.body)
    rule = HelpWidgetSuggestedArticleRule.find_by_id(res['id'])
    cached_rules = @widget.help_widget_suggested_article_rules_from_cache
    assert_equal cached_rules.first['id'], rule.id
    assert_nil cached_rules.first['filter']
    match_json(rule_pattern(rule))
  end

  def test_create_suggested_article_rules_limit
    100.times do |x|
      create_widget_suggested_article_rules(suggested_article_rule)
    end
    post :create, construct_params(suggested_article_rule_request_params)
    assert_response 400
    match_json(request_error_pattern(:rule_limit_exceeded, limit: HelpWidgets::SuggestedArticleRulesConstants::DEFAULT_RULE_LIMIT))
  ensure
    @widget.help_widget_suggested_article_rules.destroy_all
  end

  def test_create_suggested_article_rules_with_required_fields
    params = suggested_article_rule_request_params
    params[:suggested_article_rule][:filter] = params[:suggested_article_rule][:filter].slice(:value)
    params[:suggested_article_rule][:conditions][0] = params[:suggested_article_rule][:conditions].first.slice(:value)
    post :create, construct_params(params)
    assert_response 201
    res = JSON.parse(@response.body)
    rule = HelpWidgetSuggestedArticleRule.find_by_id(res['id'])
    match_json(rule_pattern(rule))
  end

  def test_create_rule_with_invalid_evaluate_on
    params = suggested_article_rule_request_params(evaluate_on: 20)
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern_with_nested_field('conditions', 'evaluate_on', "It should be one of these values: '1'", code: 'invalid_value')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_invalid_condition_name
    params = suggested_article_rule_request_params(condition_name: 20)
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern_with_nested_field('conditions', 'name', "It should be one of these values: '1'", code: 'invalid_value')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_invalid_operator
    params = suggested_article_rule_request_params(condition_operator: 20)
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern_with_nested_field('conditions', 'operator', "It should be one of these values: '1'", code: 'invalid_value')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_invalid_value
    params = suggested_article_rule_request_params(condition_value: 20)
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern_with_nested_field('conditions', 'value', 'It should be a/an String', code: 'datatype_mismatch')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_empty_value
    params = suggested_article_rule_request_params(condition_value: '')
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern_with_nested_field('conditions', 'value', 'It should not be blank as this is a mandatory field', code: 'invalid_value')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_invalid_rule_operator
    params = suggested_article_rule_request_params(rule_operator: 20)
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern('rule_operator', "It should be one of these values: '1,2'", code: 'invalid_value')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_invalid_filter_type
    params = suggested_article_rule_request_params(filter_type: 20)
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern_with_nested_field('filter', 'type', "It should be one of these values: '1,2,3'", code: 'invalid_value')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_invalid_order_by
    params = suggested_article_rule_request_params(order_by: 20)
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern_with_nested_field('filter', 'order_by', "It should be one of these values: '1'", code: 'invalid_value')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_invalid_filter_value
    params = suggested_article_rule_request_params(filter_value: 20)
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern_with_nested_field('filter', 'value', 'It should be a/an Array', code: 'datatype_mismatch')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_empty_array
    params = suggested_article_rule_request_params(filter_value: [])
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern('filter_value', 'Has 0 article, it should have minimum of 1 article and can have maximum of 5 article', code: 'invalid_value')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_duplicate_array
    article_ids = suggested_article_ids
    params = suggested_article_rule_request_params(filter_value: [article_ids[0], article_ids[0]])
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern('filter_value', "Duplicate filter_value,filter_value Must be unique, '#{article_ids[0]},#{article_ids[0]}' ", code: 'invalid_value')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_invalid_key_in_filter
    params = suggested_article_rule_request_params
    params[:suggested_article_rule][:filter][:test] = 'invalid_key'
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern('test', 'Unexpected/invalid field in request', code: 'invalid_field')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_invalid_key_in_condition
    params = suggested_article_rule_request_params
    params[:suggested_article_rule][:conditions].first[:test] = 'invalid_key'
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern('test', 'Unexpected/invalid field in request', code: 'invalid_field')
    match_json(validation_error_pattern(error))
  end

  def test_create_rule_with_invalid_key
    params = suggested_article_rule_request_params
    params[:suggested_article_rule][:test] = 'invalid_key'
    post :create, construct_params(params)
    assert_response 400
    error = bad_request_error_pattern('test', 'Unexpected/invalid field in request', code: 'invalid_field')
    match_json(validation_error_pattern(error))
  end

  def test_create_without_help_widget_article_customisation_feature
    @account.stubs(:help_widget_article_customisation_enabled?).returns(false)
    post :create, construct_params(suggested_article_rule_request_params)
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The help_widget, help_widget_article_customisation feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    @account.unstub(:help_widget_article_customisation_enabled?)
  end

  def test_create_without_help_widget_enabled
    @account.stubs(:help_widget_enabled?).returns(false)
    post :create, construct_params(suggested_article_rule_request_params)
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The help_widget, help_widget_article_customisation feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    @account.unstub(:help_widget_enabled?)
  end

  def test_update_suggested_article_rule
    article_rule = create_widget_suggested_article_rules(suggested_article_rule).first
    suggested_article_ids.pop
    put :update, construct_params(suggested_article_rule_request_params(condition_value: 'pogo', filter_value: suggested_article_ids).merge(id: article_rule.id))
    assert_response 200
    article_rule.reload
    match_json(rule_pattern(article_rule))
    assert_equal article_rule.conditions.first[:value], 'pogo'
    assert_equal article_rule.filter[:value], suggested_article_ids
  end

  def test_update_with_article_id_exceeding_max
    article_rule = create_widget_suggested_article_rules(suggested_article_rule).first
    put :update, construct_params(suggested_article_rule_request_params(condition_value: 'pogo', filter_value: [1, 2, 3, 4, 5, 6]).merge(id: article_rule.id))
    assert_response 400
    bad_request_error_pattern('filter_value', 'Has 6 article, it should have minimum of 1 article and can have maximum of 5 article', code: 'invalid_value')
  end

  def test_update_without_help_widget_enabled
    @account.stubs(:help_widget_enabled?).returns(false)
    put :update, construct_params(suggested_article_rule_request_params)
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The help_widget, help_widget_article_customisation feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    @account.unstub(:help_widget_enabled?)
  end

  def test_update_without_condition_and_filter
    article_rule = create_widget_suggested_article_rules(suggested_article_rule).first
    put :update, construct_params(suggested_article_rule_request_params.except(:conditions, :filter).merge(id: article_rule.id))
    assert_response 200
    article_rule.reload
    match_json(rule_pattern(article_rule))
  end

  def test_update_suggested_article_rule_with_single_param
    article_rule = create_widget_suggested_article_rules(suggested_article_rule).first
    params = {
      version: 'private',
      help_widget_id: @widget.id,
      suggested_article_rule: {
        conditions: [{
          value: 'first'
        }]
      }
    }
    put :update, construct_params(params.merge(id: article_rule.id))
    assert_response 200
    article_rule.reload
    match_json(rule_pattern(article_rule))
  end

  def test_update_suggested_article_rule_with_invalid_params
    article_rule = create_widget_suggested_article_rules(suggested_article_rule).first
    params = suggested_article_rule_request_params
    params[:suggested_article_rule][:test] = 'invalid_key'
    put :update, construct_params(params.merge(id: article_rule.id))
    assert_response 400
    bad_request_error_pattern('test', 'Unexpected/invalid field in request', code: 'invalid_field')
  end

  def test_delete_suggested_article_rule
    conditions = [{ evaluate_on: 'page', name: 'url', operator: 1, value: 'refund' }]
    filter = { type: 1, value: [1, 3, 4], order_by: 'hits' }
    create_widget_suggested_article_rules(conditions: conditions, filter: filter)
    delete :destroy, controller_params(version: 'v2', help_widget_id: @widget.id, id: @widget.help_widget_suggested_article_rules.last.id)
    assert_response 204
  end

  def test_delete_suggested_article_rule_not_present
    conditions = [{ evaluate_on: 'page', name: 'url', operator: 1, value: 'refund' }]
    filter = { type: 1, value: [1, 3, 4], order_by: 'hits' }
    create_widget_suggested_article_rules(conditions: conditions, filter: filter)
    delete :destroy, controller_params(version: 'v2', help_widget_id: @widget.id, id: @widget.help_widget_suggested_article_rules.last.id + 200)
    assert_response 404
  end

  def test_delete_suggested_article_rule_with_no_items
    delete :destroy, controller_params(version: 'v2', help_widget_id: @widget.id, id: @widget.help_widget_suggested_article_rules.last.try(:id).to_i + 200)
    assert_response 404
  end

  def test_delete_suggested_article_rule_without_feature
    @account.stubs(:help_widget_article_customisation_enabled?).returns(false)
    get :index, controller_params(version: 'private', help_widget_id: @widget.id)
    assert_response 403
    match_json('code' => 'require_feature',
               'message' => 'The help_widget, help_widget_article_customisation feature(s) is/are not supported in your plan. Please upgrade your account to use it.')
  ensure
    @account.unstub(:help_widget_article_customisation_enabled?)
  end

  def test_plan_based_article_customisation_features_estate_17
    sub_plan = SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_jan_17])
    SubscriptionPlan.stubs(:find_by_name).returns(sub_plan)
    create_sample_account('estate17helpwidgetcustomisation', 'estate17helpwidgetcustomisation@freshdesk.test')
    refute @account.has_features?(:help_widget_article_customisation)
  ensure
    SubscriptionPlan.unstub(:find_by_name)
    @account.destroy
  end

  def test_plan_based_article_customisation_features_estate_19
    sub_plan = SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_jan_19])
    SubscriptionPlan.stubs(:find_by_name).returns(sub_plan)
    create_sample_account('estate19helpwidgetcustomisation', 'estate19helpwidgetcustomisation@freshdesk.test')
    assert @account.has_features?(:help_widget_article_customisation)
  ensure
    SubscriptionPlan.unstub(:find_by_name)
    @account.destroy
  end
end
