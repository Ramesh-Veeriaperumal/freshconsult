class Support::SurveysController < ApplicationController

  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :load_ticket, :only => :create_for_portal
  before_filter :load_handle, :except => [:create_for_portal]
  before_filter :delta_handle

  include SupportTicketControllerMethods  
    
  def delta_handle
   redirect_to params.merge!(:controller => "support/custom_surveys") if current_account.new_survey_enabled?
  end

  def new
    send_error and return if @survey_handle.rated?
    @rating = Survey::CUSTOMER_RATINGS_BY_TOKEN.fetch(params[:rating], Survey::HAPPY)
    @account = Account.find_by_id @survey_handle.survey[:account_id]
    render :partial => 'new'
  end
  
  def create
    @rating = params[:rating]
    survey_result = @survey_handle.create_survey_result @rating
    if survey_result
      @survey_handle.survey_result.add_feedback(params[:survey][:feedback]) unless params[:survey][:feedback].blank?
      @survey_handle.destroy
    end
    render :partial => 'index', :formats => [:html]
  end
  
  def create_for_portal
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

      survey_result.add_feedback(params[:feedback]) unless params[:feedback].blank?

      redirect_to :back
    end

  end

  protected
    def load_handle
      @survey_handle = current_account.survey_handles.find_by_id_token(params[:survey_code])
      send_error if @survey_handle.blank? || @survey_handle.surveyable.blank? || archived_ticket_link
    end
    
    def send_error
      if @survey_handle.blank?
        flash[:notice] = I18n.t('support.surveys.feedback_already_done')
      elsif @survey_handle.surveyable.blank? || archived_ticket_link
        flash[:notice] = I18n.t('support.surveys.survey_closed')
      end
      redirect_to root_path
    end

    def load_ticket
      @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
      
      # Display "survey_closed" message for archived tickets
      if @ticket.blank? and current_account.features?(:archive_tickets) and 
          current_account.archive_tickets.find_by_display_id(params[:ticket_id])
        send_error I18n.t('support.surveys.survey_closed') 
      end
    end

    def archived_ticket_link
      @survey_handle.surveyable and current_account.features?(:archive_tickets) and 
          @survey_handle.surveyable.is_a?(Helpdesk::ArchiveTicket)
    end
    
end