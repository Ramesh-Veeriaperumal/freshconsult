require_relative '../../unit_test_helper'

class HelpWidgets::SuggestedArticleRulesFilterValidationTest < ActionView::TestCase
  def test_valid
    rules_filter = HelpWidgets::SuggestedArticleRulesFilterValidation.new(help_widget_id: 5)
    assert rules_filter.valid?
  end

  def test_help_widget_id_nil
    rules_filter = HelpWidgets::SuggestedArticleRulesFilterValidation.new(help_widget_id: nil)
    refute rules_filter.valid?
    error = rules_filter.errors.full_messages
    assert error.include?('Help widget datatype_mismatch')
    assert error.include?("Help widget can't be blank")
  end

  def test_help_widget_id_non_integer
    rules_filter = HelpWidgets::SuggestedArticleRulesFilterValidation.new(help_widget_id: 'st')
    refute rules_filter.valid?
    error = rules_filter.errors.full_messages
    assert error.include?('Help widget datatype_mismatch')
  end

  def test_help_widget_id_negative
    rules_filter = HelpWidgets::SuggestedArticleRulesFilterValidation.new(help_widget_id: -1)
    refute rules_filter.valid?
    error = rules_filter.errors.full_messages
    assert error.include?('Help widget datatype_mismatch')
  end
end
