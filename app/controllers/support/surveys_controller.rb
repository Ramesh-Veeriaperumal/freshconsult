class Support::SurveysController < ApplicationController

  before_filter :load_handle, :except => [:create_for_portal]
  
  include SupportTicketControllerMethods

  def new
  	send_error and return if @survey_handle.rated?
  	
    @rating = Survey::CUSTOMER_RATINGS_BY_TOKEN.fetch(params[:rating], Survey::HAPPY)
    @survey_handle.create_survey_result @rating
    @account = Account.find_by_id @survey_handle.survey[:account_id]
    render :partial => 'new'
  end
  
  def create
    
    if @survey_handle.survey_result
      @survey_handle.survey_result.add_feedback(params[:survey][:feedback])
      @survey_handle.destroy
    end

    flash[:notice] = I18n.t('support.surveys.thanks_for_feedback')
    redirect_to root_path
  end
  
  def create_for_portal

    @ticket = current_account.tickets.find_by_id(params[:ticket_id])
    
    unless can_access_support_ticket?
      access_denied
    else        
      survey_result = @ticket.survey_results.create({        
        :survey_id => current_account.survey.id,                
        :surveyable_type => "Helpdesk::Ticket",
        :customer_id => @ticket.requester_id,
        :agent_id => @ticket.responder_id,
        :group_id => @ticket.group_id,                
        :rating => params[:rating]
      })

      survey_result.add_feedback(params[:feedback])

      redirect_to :back
    end

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
