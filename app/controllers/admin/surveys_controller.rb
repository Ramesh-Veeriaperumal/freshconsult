class Admin::SurveysController < Admin::AdminController
     
  before_filter { |c| c.requires_feature :surveys }
  before_filter :delta_handle
    
  def delta_handle
   redirect_to params.merge!(:controller => "admin/custom_surveys") if current_account.features?(:custom_survey)
  end
 
  def index
    @account = current_account
    @survey = current_account.survey
     respond_to do |format|
      format.html
     end
  end
  
  def enable    
       current_account.features.survey_links.create     
       current_account.reload  
  end
  
  def disable
  	   current_account.features.survey_links.destroy
  	   current_account.reload  	
  end
  
  def new
  
  end

  def edit

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