require_relative '../api/unit_test_helper'
require_relative '../../spec/support/note_helper'
require_relative '../api/helpers/help_widgets_test_helper'
require Rails.root.join('spec', 'support', 'products_helper.rb')

class HelpWidgetSuggestedArticleRuleTest < ActiveSupport::TestCase
  include HelpWidgetsTestHelper
  include ProductsHelper

  def setup
    @account = (Account.first || create_test_account).make_current
    @product = @account.products.first || create_product
    @widget = create_widget(product_id: @product.id)
  end

  def teardown
    @widget.destroy
    @product.destroy
    super
  end

  def test_create_with_validation_suggested_article_rule
    article_rule = @widget.help_widget_suggested_article_rules.build
    refute article_rule.save
    article_rule.filter = { value: 'test' }
    refute article_rule.save
    article_rule.conditions = [{ value: [1, 2] }]
    assert article_rule.save
    rule = @account.help_widgets.find(@widget.id).help_widget_suggested_article_rules.first
    assert_equal rule.filter, value: 'test'
  end

  def test_update_with_validation_suggested_article_rule
    article_rule = @widget.help_widget_suggested_article_rules.build
    article_rule.filter = { value: 'test' }
    article_rule.conditions = [{ value: [1, 2] }]
    assert article_rule.save
    article_rule.filter = nil
    refute article_rule.save
    article_rule.filter = {}
    refute article_rule.save
    article_rule.filter = { value: 'changed' }
    article_rule.conditions = nil
    refute article_rule.save
    article_rule.conditions = []
    refute article_rule.save
    article_rule.conditions = [{ value: [4, 5] }]
    assert article_rule.save
    rule = @account.help_widgets.find(@widget.id).help_widget_suggested_article_rules.first
    assert_equal rule.filter, value: 'changed'
  end
end
