class Admin::SurveysController < Admin::AdminController
     
  before_filter { |c| c.requires_feature :surveys }
     
  def index
    @account = current_account    
    @survey = current_account.survey
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

end