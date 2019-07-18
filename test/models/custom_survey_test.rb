require_relative '../test_helper'
require Rails.root.join('test', 'core', 'helpers', 'account_test_helper.rb')
class CustomSurveyTest < ActiveSupport::TestCase
  include AccountTestHelper

  def setup
    super
    create_test_account if @account.nil?
  end

  def test_satisfaction_survey_html_renders_response
    ActionView::Renderer.any_instance.stubs(:render).returns('')
    response = Account.current.custom_surveys.satisfaction_survey_html(Account.current.tickets.first)
    assert_equal response, ''
  end

  def test_custom_survey_translation_returns_nil_when_check_fails
    translation = Account.current.custom_surveys.first.translation_record(Language.find_by_code('fr'))
    assert_equal translation, nil
  end
end
