class Support::CustomSurveysController < SupportController #for Portal Customization

  skip_before_filter :check_privilege, except: [:preview]
  before_filter :preview_feature_check, only: [:preview]
  before_filter :load_survey, only: [:preview]
  before_filter :load_handle, :only => [:new_via_handle, :hit]
  before_filter :load_translation, only: [:new_via_handle]
  before_filter :backward_compatibility_check, :only => [:hit]
  before_filter :load_ticket,         :only => :new_via_portal
  before_filter :load_survey_result,  :only => :create
  
  include SupportTicketControllerMethods
  helper Admin::CustomSurveysHelper

  def new_via_handle
    respond_to do |format|
      format.html do
        @rating = CustomSurvey::Survey::CUSTOMER_RATINGS_BY_TOKEN.fetch(params[:rating], CustomSurvey::Survey::EXTREMELY_HAPPY)
        @survey_code = params[:survey_code]
        @rating_via_handle = true
        @source = params[:source]
        set_portal_page :csat_survey
        render 'new'
      end
    end
  end
  
  def hit
    respond_to do |format|
      format.json do
        @rating = params[:rating]
        @survey_handle.record_survey_result(@rating, params[:source]) unless @survey_handle.preview?
          render :json => {:submit_url => @survey_handle.feedback_url(@rating)}.to_json
      end
    end
  end

  def new_via_portal
    @rating = params[:rating]
    unless can_access_support_ticket?
      access_denied
    else
      @survey_handle = if @ticket.resolved?
        CustomSurvey::SurveyHandle.create_handle_for_portal(@ticket, EmailNotification::TICKET_RESOLVED)
      elsif @ticket.closed?
        CustomSurvey::SurveyHandle.create_handle_for_portal(@ticket, EmailNotification::TICKET_CLOSED)
      end

      if @survey_handle.nil?
         flash[:notice] = t('support.tickets.ticket_survey.survey_on_open_ticket')
         render :json => {:url_new_via_handle => ""}
       else
         survey_handle_hash = @survey_handle.id_token
         render :json => {:url_new_via_handle => "#{support_customer_custom_survey_url(survey_handle_hash, CustomSurvey::Survey::CUSTOMER_RATINGS[@rating.to_i])}?source=#{CustomSurvey::SurveyHandle::NEW_VIA_PORTAL}"}
       end
    end
  end

  def create
    @survey_result.update_result_and_feedback(params)
    language = Language.find_by_code(@survey_result.try(:surveyable).try(:requester_language))
    translation_record = @survey_result.survey.translation_record(language) if language.present?
    thanks_message = translation_record.translations['feedback_response_text'] if translation_record.present?
    render json: { thanks_message: thanks_message || @survey_result.survey.feedback_response_text }
  end

  def preview
    respond_to do |format|
      format.html do
        @survey_preview = true
        set_portal_page :csat_survey
        render 'new'
      end
    end
  end

  protected
    # To support survey handles which are sent with older ratings before migration
    def backward_compatibility_check
      allowed_choices = @survey_handle.survey.choice_names.collect{|c| c[0]}
      rating = CustomSurvey::Survey::CUSTOMER_RATINGS_BY_TOKEN.fetch(params[:rating], CustomSurvey::Survey::EXTREMELY_HAPPY)
      if !allowed_choices.include?(rating) and @survey_handle.survey.default?
        params[:rating] = CustomSurvey::Survey::CLASSIC_TO_CUSTOM_RATING[params[:rating]]
      end
    end

    def preview_feature_check
      render_404 if !current_account.custom_survey_enabled? || !current_account.csat_translations_enabled?
    end

    def load_survey
      @survey = scoper.undeleted.where(id: params[:id]).first
      render_404 && return if !@survey
      @survey_language = Language.current
      @translated_survey = @survey.translation_record(Language.current) if current_account.language != @survey_language
    end

    def scoper
      current_account.custom_surveys
    end

    def load_handle
      @survey_handle = current_account.custom_survey_handles.find_by_id_token(params[:survey_code])
      if (@survey_handle.blank? || @survey_handle.rated? || @survey_handle.surveyable.blank? ||
          archived_ticket_link? || @survey_handle.survey_result_id || @survey_handle.survey.nil? ||
          @survey_handle.survey.deleted?)
        send_handle_error
        @survey_handle.destroy if @survey_handle.present? && !@survey_handle.survey.deleted?
      end
      if current_user.present? && ((@survey_handle.surveyable.requester_id != current_user.id) && current_user.helpdesk_agent?)
        send_error I18n.t('support.surveys.agent_feedback_error')
      end
    end

    def load_translation
      @language = Language.find_by_code(@survey_handle.try(:surveyable).try(:requester_language))
      @translation_record = @survey_handle.survey.translation_record(@language) if @survey_handle && @language.present?
    end
    
    def load_survey_result
      @survey_result = current_account.custom_survey_results.preload(survey: [survey_questions: [:survey, :custom_field_choices_desc]]).find(params[:survey_result])
      send_result_error unless @survey_result
    end
    
    def send_handle_error
      if @survey_handle.blank? || @survey_handle.survey.deleted?
        send_error I18n.t('support.surveys.handle_expired') 
      elsif (@survey_handle.surveyable.blank? or archived_ticket_link?) && !@survey_handle.preview?
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
      if @ticket.blank? and current_account.features_included?(:archive_tickets) and
          current_account.archive_tickets.find_by_display_id(params[:ticket_id])
        send_error I18n.t('support.surveys.survey_closed') 
      end
      unless CustomSurvey::Survey::CUSTOMER_RATINGS.include?(params[:rating].to_i)
        send_error I18n.t('support.surveys.survey_closed') 
      end
    end

    def archived_ticket_link?
      @survey_handle.surveyable and current_account.features_included?(:archive_tickets) and 
        @survey_handle.surveyable.is_a?(Helpdesk::ArchiveTicket)
    end
end
