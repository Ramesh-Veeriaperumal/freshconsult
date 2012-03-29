class Admin::SurveysController < Admin::AdminController
     
  before_filter { |c| c.requires_feature :surveys }
     
  def index
    @account = current_account    
    @survey = current_account.survey
    @scoreboard_ratings = current_account.scoreboard_ratings
  end
  
  def enable
    if(params[:account][:features][:survey_links] == "1")
       current_account.features.survey_links.create
       @enable = true
    else
       @enable = false
       current_account.features.survey_links.destroy
    end    
  end
  
  def update
    @survey = current_account.survey
    @survey.store(params[:survey])        
  end
  
  #scoreboard related
  def enable_sb
    if(params[:account][:features][:scoreboard] == "1")
       current_account.features.scoreboard.create
       @enable_sb = true
    else
       @enable_sb = false
       current_account.features.scoreboard.destroy
    end    
  end

end