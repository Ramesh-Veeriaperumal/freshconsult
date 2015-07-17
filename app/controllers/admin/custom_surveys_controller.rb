class Admin::CustomSurveysController < Admin::AdminController
     
  before_filter { |c| c.requires_feature :custom_survey }
  before_filter :escape_html_entities_in_json
  before_filter :check_survey_limit, :only => [:new, :create]
  before_filter :format_custom_choices_attribs, :only => [:create,:update]
  inherits_custom_fields_controller
  
  def index
    @account = current_account
    @surveys = current_account.custom_surveys.sort_by{ |survey| survey[:active]}.reverse
  end
  
  def edit
    @account = current_account
    @survey_id = params[:id]
    @surveys = current_account.custom_surveys
    survey = @surveys.find(@survey_id)
    @layout_params = {    
                                        action:"update" , 
                                        method: "put" , 
                                        active:survey.active? , 
                                        title:survey.title_text ,
                                        id:@survey_id , 
                                        url: admin_custom_surveys_path + "/" +@survey_id 
                                  }
    @survey_details = {
                                        survey: survey.to_json({
                                                      :except => :account_id
                                                    }) , 
                                        survey_questions:survey.feedback_questions.to_json,
                                        default_question: survey.default_question.to_json,
                                        survey_result_exists: !survey.survey_results.blank? 
                                }
     flash[:notice] = t(:'admin.surveys.new_layout.result_exist_msg') unless survey.survey_results.blank?
  end

  def new
    @account = current_account
    @surveys = current_account.custom_surveys
    @layout_params = {   
                                       action: "create", 
                                       method: "post" , 
                                       active:false , 
                                       title: "" , 
                                       id: "" , 
                                       url: admin_custom_surveys_path
                                  }
  end

  def enable
      current_account.features.survey_links.create
      current_account.reload
      unless current_account.custom_surveys.active.blank?
          survey_active = current_account.custom_surveys.active.first
          survey_active.disable
      end
      survey = current_account.custom_surveys.find(params[:id])
      survey.enable
      result = {:active => survey.id}
      result["inactive"] = survey_active.id unless survey_active.blank?
      render :json => result.to_json
  end
  
  def disable
         survey = current_account.custom_surveys.find(params[:id])
         survey.disable 
    	   current_account.features.survey_links.destroy 
    	   current_account.reload
         render :json => {inactive: survey.id}
  end
  
  def destroy
        survey = current_account.custom_surveys.find(params[:id])
        survey.destroy unless (survey.default? || survey.active?)
        flash[:notice] = t(:'admin.surveys.successfully_deleted')
        render :json => {id: survey.id }
  end

  def create
        @survey = current_account.custom_surveys.new
        update
  end
  
  def update
    msg = params["id"].blank? ? t(:'admin.surveys.successfully_created') : t(:'admin.surveys.successfully_updated')
    @survey = @survey || current_account.custom_surveys.find(params[:id])
      if JSON.parse(params["survey"])["active"]
          current_account.survey.disable unless (current_account.custom_surveys.active.blank? || 
                                    (!current_account.custom_surveys.active.blank? && current_account.custom_surveys.active.first.id == params[:id].to_i))
      end
      unless params["deleted"].blank?
        questions = params["deleted"].split(",")
        @survey.survey_questions.where(:id => questions).destroy_all
      end
      @survey.store(params)
    super
    flash[:notice] = msg
    @surveys = current_account.custom_surveys
    result_set = {surveys:@surveys.to_json}
    if !@errors.blank?
       result_set["errors"] = @errors
    end
    render :json => result_set
  end

  def test_survey
    if current_user.agent?
      ticket = CustomSurvey::Survey.sample_ticket(current_user,params[:id])
      e_notification = ticket.account.email_notifications.find_by_notification_type(EmailNotification::PREVIEW_EMAIL_VERIFICATION)
      Helpdesk::TicketNotifier.deliver_agent_notification(ticket.responder, ticket.requester.email, e_notification, ticket, '', params[:id])
    else
      flash[:notice] = t(:'admin.surveys.survey_preview_error')
    end
      render :json => {}
  end

  private 

  def format_custom_choices_attribs
    questions = JSON.parse params[:jsonData]
    questions.each_with_index do |question, index|
      custom_format = []
      question['choices'].each_with_index do |choice,cindex|
        position = (cindex+1)
        choice_format  = {:position => position, :_destroy => 0, :value => choice[0], :face_value => choice[1]}
        choice_format[:id] = question["choiceMap"][position.to_s] unless question["choiceMap"].blank?
        custom_format << choice_format
      end
      question["custom_field_choices_attributes"] = custom_format
      ["choices","choiceMap","name","deleted","survey_id"].each do |attrib|
          question.delete attrib
      end
    end
    params[:jsonData] = questions.to_json
    if questions.length > CustomSurvey::Survey::QUESTIONS_LIMIT
      render :json => {
                    :error => t(:'admin.surveys.questions.limit_exceed_error', 
                    :count => CustomSurvey::Survey::QUESTIONS_LIMIT)
                }
    end
  end
      
  def check_survey_limit
    if current_account.custom_surveys.length >=CustomSurvey::Survey::SURVEYS_LIMIT
      flash[:notice] = t(:'admin.surveys.limit_exceed_error', :count => CustomSurvey::Survey::SURVEYS_LIMIT)
      redirect_to admin_custom_surveys_path
    end
  end

  def scoper_class
        CustomSurvey::SurveyQuestion
  end

  def index_scoper
        @index_scoper || @survey.survey_questions.all
  end  

  def escape_html_entities_in_json
    ActiveSupport::JSON::Encoding.escape_html_entities_in_json = true
  end

end