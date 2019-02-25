require_relative '../../test_helper'
require Rails.root.join('test', 'api', 'helpers', 'surveys_test_helper.rb')

class SurveyTest < ActiveSupport::TestCase
  include SurveysTestHelper

  def setup
    super
    Sidekiq::Worker.clear_all
    before_all
  end

  @@before_all_run = false

  def before_all
    return if @@before_all_run
    @account.launch(:surveys_central_publish)
    CentralPublishWorker::SurveyWorker.jobs.clear
    @@before_all_run = true
  end

  def test_survey_payload
    create_survey(1, true)
    survey = @account.surveys.last
    payload = survey.central_publish_payload.to_json
    payload.must_match_json_expression(central_survey_pattern(survey))
  end
end
