class Support::CustomSurveysController < ApplicationController

  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :load_handle, :backward_compatibility_check, :only => [:new]
  before_filter :load_ticket, :only => :create_for_portal
  before_filter :load_survey_result, :only => [:create]
  
  include SupportTicketControllerMethods

  def new    
    @rating = CustomSurvey::Survey::CUSTOMER_RATINGS_BY_TOKEN.fetch(params[:rating], CustomSurvey::Survey::EXTREMELY_HAPPY)
    @survey_handle.create_survey_result @rating unless @survey_handle.preview?    
    @survey_handle.destroy
      render :partial => 'new'
  end
  
  def create
    if @survey_result
      @survey_result.add_feedback(params) unless params.blank?
    end

    render :json => {
        thanks_message: @survey_result.survey.feedback_response_text
    }
  end
  
  def create_for_portal
    @rating = params[:rating]
    unless can_access_support_ticket?
        access_denied
    else    
        if @ticket.resolved?
          @survey_handle = CustomSurvey::SurveyHandle.create_handle_for_notification(@ticket,EmailNotification::TICKET_RESOLVED,nil,false, true) 
        elsif @ticket.closed?
          @survey_handle = CustomSurvey::SurveyHandle.create_handle_for_notification(@ticket,EmailNotification::TICKET_CLOSED,nil,false, true)
        end

        @survey_handle.create_survey_result @rating 
        @survey_handle.destroy 
        flash[:notice] = I18n.t('support.surveys.thanks_for_feedback')
        render :partial => 'new'
    end
  end

  protected
    # To support survey handles which are sent with older ratings before migration
    def backward_compatibility_check
      allowed_choices = @survey_handle.survey.choice_names.collect{|c| c[0]}
      rating = CustomSurvey::Survey::CUSTOMER_RATINGS_BY_TOKEN.fetch(params[:rating], CustomSurvey::Survey::EXTREMELY_HAPPY)
      classic_vs_custom = {
          "happy" => "extremely_happy",
          "neutral" => "neutral",
          "unhappy" => "extremely_unhappy"
      }
      if (!allowed_choices.include?rating) and @survey_handle.survey.default?
        params[:rating] = classic_vs_custom[params[:rating]]
      end
    end

    def load_handle
      @survey_handle = current_account.custom_survey_handles.find_by_id_token(params[:survey_code])
      send_handle_error if (@survey_handle.blank? || @survey_handle.surveyable.blank? || 
        archived_ticket_link? || @survey_handle.rated?)
    end


    
    def load_survey_result
      @survey_result = current_account.custom_survey_results.find(params[:survey_result])
      send_result_error unless @survey_result
    end
    
    def send_handle_error
      if @survey_handle.blank?
        send_error I18n.t('support.surveys.handle_expired') 
      elsif @survey_handle.surveyable.blank? or archived_ticket_link?
        send_error I18n.t('support.surveys.survey_closed') 
      elsif @survey_handle.rated?
        send_error I18n.t('support.surveys.feedback_already_done') 
      end
    end
    
    def send_result_error
      send_error I18n.t('support.surveys.no_survey_result_error')
    end
    
    def send_error msg
      flash[:notice] = msg
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

    def archived_ticket_link?
      @survey_handle.surveyable and current_account.features?(:archive_tickets) and 
          @survey_handle.surveyable.is_a?(Helpdesk::ArchiveTicket)
    end
end
