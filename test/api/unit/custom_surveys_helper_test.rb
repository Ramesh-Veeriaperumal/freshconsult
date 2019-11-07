require_relative '../unit_test_helper'
require 'admin/custom_surveys_helper'

class CustomSurveysHelperTest < ActionView::TestCase
  include Admin::CustomSurveysHelper

  def setup
    super
    Account.stubs(:current).returns(Account.first)
    @survey = Account.current.surveys.first
    @survey_handle = Account.current.tickets.first.survey_handles.build
    @survey_handle.survey = @survey
    @survey_handle.id_token = rand(10_000)
    @survey_handle.save!
    @rating = 103
  end

  def teardown
    Account.unstub(:current)
  end

  def stub_for_csat_translations
    Account.current.stubs(:custom_translations_enabled?).returns(true)
    Account.current.stubs(:portal_languages_objects).returns([Language.find_by_code('de')])
    Account.current.stubs(:supported_languages_objects).returns([Language.find_by_code('de'), Language.find_by_code('fr'), Language.find_by_code('es')])
    @survey_statuses = { 5 => 1 } 
  end

  def unstub_for_csat_translations
    Account.any_instance.unstub(:custom_translations_enabled?)
    Account.any_instance.unstub(:all_portal_languages)
    @survey_statuses = nil
  end

  def test_custom_surveys_url_contains_language_if_key_is_present
    assert custom_survey_url(@survey_handle, @rating, Language.find_by_code('fr')).include?('/fr/')
  end

  def test_custom_surveys_does_not_contain_language_if_key_is_not_present
    assert custom_survey_url(@survey_handle, @rating).exclude?('/fr/')
  end

  def test_portal_languages
    stub_for_csat_translations
    assert portal_languages_status.first['status'].equal?(1)
    unstub_for_csat_translations
  end

  def test_support_languages
    stub_for_csat_translations
    assert hidden_languages_status.last['status'].equal?(0)
    unstub_for_csat_translations
  end
end
