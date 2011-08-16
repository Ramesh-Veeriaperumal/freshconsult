class Admin::SurveysController < Admin::AdminController
  def index
    @survey = current_account.survey
    @survey_points = @survey.survey_points
  end

end
