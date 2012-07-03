class Support::SurveysController < ApplicationController
  before_filter :load_handle
  
  def new
  	send_error and return if @survey_handle.rated?
  	
    @rating = Survey::CUSTOMER_RATINGS_BY_TOKEN.fetch(params[:rating], Survey::HAPPY)
    @survey_handle.create_survey_result @rating
    @account = Account.find_by_id @survey_handle.survey[:account_id]
    render :partial => 'new'
  end
  
  def create
    #2. Clear the handle record.
    if @survey_handle.survey_result
      @survey_handle.survey_result.add_feedback(params[:survey][:feedback])
      @survey_handle.destroy
    end
    
    flash[:notice] = I18n.t('support.surveys.thanks_for_feedback')
    redirect_to root_path
  end
  
  protected
    def load_handle
      @survey_handle = current_account.survey_handles.find_by_id_token(params[:survey_code])
      send_error unless @survey_handle
    end
    
    def send_error
      flash[:warning] = I18n.t('support.surveys.feedback_already_done')
      redirect_to root_path
    end
    
end
