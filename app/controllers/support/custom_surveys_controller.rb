class Support::CustomSurveysController < SupportController #for Portal Customization

  skip_before_filter :check_privilege, :verify_authenticity_token
  before_filter :load_handle, :backward_compatibility_check, :only => [:new]
  before_filter :load_ticket,         :only => :create_for_portal
  before_filter :load_survey_result,  :only => :create
  
  include SupportTicketControllerMethods

  def new
    @rating = CustomSurvey::Survey::CUSTOMER_RATINGS_BY_TOKEN.fetch(params[:rating], CustomSurvey::Survey::EXTREMELY_HAPPY)
    @survey_handle.record_survey_result @rating unless @survey_handle.preview?
    respond_to do |format|
      format.html { set_portal_page :csat_survey }
    end
  end
  
  def create
    @survey_result.update_result_and_feedback(params)
    render :json => {thanks_message: @survey_result.survey.feedback_response_text}
  end
  
  def create_for_portal
    @rating = params[:rating]
    unless can_access_support_ticket?
      access_denied
    else    
      @survey_handle = if @ticket.resolved?
        CustomSurvey::SurveyHandle.create_handle_for_portal(@ticket, EmailNotification::TICKET_RESOLVED)
      elsif @ticket.closed?
        CustomSurvey::SurveyHandle.create_handle_for_portal(@ticket, EmailNotification::TICKET_CLOSED)
      end
      @survey_handle.record_survey_result @rating

      flash[:notice] = I18n.t('support.surveys.thanks_for_feedback')
      respond_to do |format|
        format.html do
          set_portal_page :csat_survey 
          render 'new'
        end
      end
    end
  end

  protected
    # To support survey handles which are sent with older ratings before migration
    def backward_compatibility_check
      allowed_choices = @survey_handle.survey.choice_names.collect{|c| c[0]}
      rating = CustomSurvey::Survey::CUSTOMER_RATINGS_BY_TOKEN.fetch(params[:rating], CustomSurvey::Survey::EXTREMELY_HAPPY)
      classic_vs_custom = {
          "happy"   => "extremely_happy",
          "neutral" => "neutral",
          "unhappy" => "extremely_unhappy"
      }
      if (!allowed_choices.include?rating) and @survey_handle.survey.default?
        params[:rating] = classic_vs_custom[params[:rating]]
      end
    end

    def load_handle
      @survey_handle = current_account.custom_survey_handles.find_by_id_token(params[:survey_code])
      if (@survey_handle.blank? || @survey_handle.rated? || @survey_handle.surveyable.blank? ||
          archived_ticket_link? || @survey_handle.survey_result_id || @survey_handle.survey.nil?)
        send_handle_error
        @survey_handle.destroy if @survey_handle.present?
      end
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

    def cache_enabled? #survey_handle may refer to different surveys
      false
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
