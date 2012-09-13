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
    unless invalid_params?
      @survey.store(params[:survey])        
      flash[:notice] = t(:'admin.surveys.successfully_updated')
    else
      flash[:notice] = t(:'admin.surveys.error_updated')
    end
  end

  def invalid_params?
      survey_params = params[:survey]
      survey_params[:link_text].blank? || survey_params[:happy_text].blank? ||
                      survey_params[:unhappy_text].blank? || survey_params[:neutral_text].blank?
  end

end