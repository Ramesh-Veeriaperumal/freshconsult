class Admin::SurveysController < Admin::AdminController
     
  before_filter { |c| c.requires_feature :surveys }
     
  def index
    @account = current_account
    @survey = current_account.survey
  end
  
  def enable    
       current_account.features.survey_links.create     
       current_account.reload  
  end
  
  def disable
  	   current_account.features.survey_links.destroy
  	   current_account.reload  	
  end
  
  def update
    @survey = current_account.survey
    @survey.store(params[:survey])        
  end

end