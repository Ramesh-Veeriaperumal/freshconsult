class Admin::SurveysController < Admin::AdminController
  def index
    @survey = current_account.survey
    @scoreboard_ratings = current_account.scoreboard_ratings
  end

end
