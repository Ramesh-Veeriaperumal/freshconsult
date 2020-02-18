require_relative '../../unit_test_helper'
require Rails.root.join('test', 'api', 'helpers', 'help_widgets_test_helper.rb')

class HelpWidgets::SuggestedArticleRulesValidationTest < ActionView::TestCase
  include HelpWidgetsTestHelper

  def test_valid
    rules = HelpWidgets::SuggestedArticleRulesValidation.new(suggested_article_rule(filter_value: [1]))
    assert rules.valid?(:create)
  end

  def test_without_condition
    param = suggested_article_rule(filter_value: [1])
    param.delete(:conditions)
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    assert_equal({ conditions: "can't be blank" }, errors)
    error = rules_filter.errors.full_messages
    assert error.include?("Conditions can't be blank")
  end

  def test_without_evaluate_on
    param = suggested_article_rule(filter_value: [1])
    param[:conditions].first.delete(:evaluate_on)
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    assert rules_filter.valid?(:create)
  end

  def test_with_invalid_evaluate_on
    param = suggested_article_rule(filter_value: [1])
    param[:conditions].first[:evaluate_on] = 20
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ conditions: :not_included }, errors)
    assert_equal({ list: '1', nested_field: :evaluate_on }, error_options[:conditions])
    error = rules_filter.errors.full_messages
    assert error.include?('Conditions not_included')
  end

  def test_without_condition_name
    param = suggested_article_rule(filter_value: [1])
    param[:conditions].first.delete(:name)
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    assert rules_filter.valid?(:create)
  end

  def test_with_invalid_condition_name
    param = suggested_article_rule(filter_value: [1])
    param[:conditions].first[:name] = 20
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ conditions: :not_included }, errors)
    assert_equal({ list: '1', nested_field: :name }, error_options[:conditions])
    error = rules_filter.errors.full_messages
    assert error.include?('Conditions not_included')
  end

  def test_without_condition_operator
    param = suggested_article_rule(filter_value: [1])
    param[:conditions].first.delete(:operator)
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    assert rules_filter.valid?(:create)
  end

  def test_with_invalid_condition_operator
    param = suggested_article_rule(filter_value: [1])
    param[:conditions].first[:operator] = 20
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ conditions: :not_included }, errors)
    assert_equal({ list: '1', nested_field: :operator }, error_options[:conditions])
    error = rules_filter.errors.full_messages
    assert error.include?('Conditions not_included')
  end

  def test_without_condition_value
    param = suggested_article_rule(filter_value: [1])
    param[:conditions].first.delete(:value)
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ conditions: :datatype_mismatch }, errors)
    assert_equal({ expected_data_type: String, code: :missing_field, nested_field: :value }, error_options[:conditions])
    error = rules_filter.errors.full_messages
    assert error.include?('Conditions datatype_mismatch')
  end

  def test_condition_value_with_empty
    param = suggested_article_rule(filter_value: [1])
    param[:conditions].first[:value] = ''
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ conditions: :blank }, errors)
    assert_equal({ expected_data_type: String, nested_field: :value }, error_options[:conditions])
    error = rules_filter.errors.full_messages
    assert error.include?('Conditions blank')
  end

  def test_without_rule_operator
    param = suggested_article_rule(filter_value: [1])
    param.delete(:rule_operator)
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    assert rules_filter.valid?(:create)
  end

  def test_with_invalid_rule_operator
    param = suggested_article_rule(filter_value: [1])
    param[:rule_operator] = 20
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ rule_operator: :not_included }, errors)
    assert_equal({ list: '1,2' }, error_options[:rule_operator])
    error = rules_filter.errors.full_messages
    assert error.include?('Rule operator not_included')
  end

  def test_without_filter
    param = suggested_article_rule(filter_value: [1])
    param.delete(:filter)
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    assert_equal({ filter: "can't be blank" }, errors)
    error = rules_filter.errors.full_messages
    assert error.include?("Filter can't be blank")
  end

  def test_without_filter_type
    param = suggested_article_rule(filter_value: [1])
    param[:filter].delete(:type)
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    assert rules_filter.valid?(:create)
  end

  def test_with_invalid_filter_type
    param = suggested_article_rule(filter_value: [1])
    param[:filter][:type] = 20
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ filter: :not_included }, errors)
    assert_equal({ list: '1,2,3', nested_field: :type }, error_options[:filter])
    error = rules_filter.errors.full_messages
    assert error.include?('Filter not_included')
  end

  def test_without_order_by
    param = suggested_article_rule(filter_value: [1])
    param[:filter].delete(:order_by)
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    assert rules_filter.valid?(:create)
  end

  def test_with_invalid_order_by
    param = suggested_article_rule(filter_value: [1])
    param[:filter][:order_by] = 20
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ filter: :not_included }, errors)
    assert_equal({ list: '1', nested_field: :order_by }, error_options[:filter])
    error = rules_filter.errors.full_messages
    assert error.include?('Filter not_included')
  end

  def test_without_filter_value
    param = suggested_article_rule(filter_value: [1])
    param[:filter].delete(:value)
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ filter: :datatype_mismatch }, errors)
    assert_equal({ expected_data_type: Array, code: :missing_field, nested_field: :value }, error_options[:filter])
    error = rules_filter.errors.full_messages
    assert error.include?('Filter datatype_mismatch')
  end

  def test_with_invalid_filter_value
    param = suggested_article_rule(filter_value: [1])
    param[:filter][:value] = 20
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ filter: :datatype_mismatch }, errors)
    assert_equal({ expected_data_type: Array, nested_field: :value }, error_options[:filter])
    error = rules_filter.errors.full_messages
    assert error.include?('Filter datatype_mismatch')
  end

  def test_with_duplicate_filter_value
    param = suggested_article_rule(filter_value: [1, 1])
    rules_filter = HelpWidgets::SuggestedArticleRulesValidation.new(param)
    refute rules_filter.valid?(:create)
    errors = rules_filter.errors.sort.to_h
    error_options = rules_filter.error_options.sort.to_h
    assert_equal({ filter_value: :duplicate_not_allowed }, errors)
    assert_equal({ conditions: {}, filter: {}, list: '1,1', name: 'filter_value', rule_operator: {} }, error_options)
    error = rules_filter.errors.full_messages
    assert error.include?('Filter value duplicate_not_allowed')
  end
end
