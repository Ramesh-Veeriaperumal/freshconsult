class Admin::CustomSurveysController < Admin::AdminController

  before_filter { |c| current_account.new_survey_enabled? }
  before_filter :redirect_to_default_survey,          :if   => :default_survey_feature_enabled?
  before_filter :escape_html_entities_in_json
  before_filter :check_survey_limit,                  :only => [:new,    :create]
  before_filter :validate_question_limit,       :only => [:create, :update]
  before_filter :load_survey,                         :only => [:edit,   :update, :destroy, :activate, :deactivate, :test_survey]
  inherits_custom_fields_controller

  def index
    @account = current_account
    @surveys = sorted_scoper
  end

  def new
    @account = current_account
    @surveys = scoper
    @layout_params = {
      action:     "create",
      method:     "post",
      active:     false,
      default:    false,
      title:      "",
      id:         "",
      url:        admin_custom_surveys_path,
      cancelUrl:  current_account.default_survey_enabled? ? "/admin/home" : admin_custom_surveys_path
    }
  end

  def create
    @survey = scoper.new
    update
    @survey.activate if survey_data[:active]
  end  

  def edit
    @account = current_account
    @surveys = scoper
    @layout_params = {
      action:       "update",
      method:       "put",
      active:       @survey.active?,
      default:      @survey.default?,
      title:        @survey.title_text,
      id:           @survey_id,
      url:          admin_custom_survey_path(@survey_id),
      cancelUrl:    current_account.default_survey_enabled? ? "/admin/home" : admin_custom_surveys_path
    }
    @survey_details = {
      survey:               @survey.to_json({:except => :account_id}),
      survey_questions:     @survey.feedback_questions.to_json,
      default_question:     @survey.default_question.to_json,
      survey_result_exists: !@survey.survey_results.blank? 
    }
    flash[:notice] = t(:'admin.surveys.new_layout.result_exist_msg_v2') if @survey.survey_results.present? &&
                                                                         !@survey.default?
  end  

  def update
    if @survey.store(survey_data)
      update_questions @survey.id
      params[:jsonData] = survey_questions_data.to_json
      super
      @surveys = scoper
      result_set = {surveys: @surveys.to_json}
      result_set['redirect_url'] = edit_admin_custom_survey_path(@survey.id) if @errors.present?
    else
      @errors = @survey.errors
      result_set = {'errors' => @errors}
    end
    result_set['default_survey_enabled'] = current_account.default_survey_enabled?
    flash[:notice] = @survey_id.blank? ? t(:'admin.surveys.successfully_created_v2') : 
                                         t(:'admin.surveys.successfully_updated_v2') if @errors.blank?
    render :json => result_set
  end  

  def destroy
    @survey.deleted = true
    @survey.save unless (@survey.default? || @survey.active?)
    flash[:notice] = t(:'admin.surveys.successfully_deleted')
    render :json => { id: @survey.id }
  end

  def activate
    current_active_survey = current_account.active_custom_survey_from_cache
    @survey.activate
    result = {:active => @survey.id}
    result["inactive"] = current_active_survey.id unless current_active_survey.blank?
    render :json => result.to_json
  end

  def deactivate
    @survey.deactivate
    render :json => {inactive: @survey.id}
  end

  def test_survey
    if current_user.agent?
      Admin::CustomSurveysMailer.send_later(:deliver_preview_email, :survey_id => params[:id], :user_id => current_user.id)
    else
      flash[:notice] = t(:'admin.surveys.survey_preview_error')
    end
    render :json => {}
  end

  private

    def survey_data
      @survey_data ||= JSON.parse(params[:survey]).symbolize_keys
    end

    def survey_questions_data
      @survey_questions_data ||= JSON.parse(params[:jsonData])
    end

    def redirect_to_default_survey
      default_survey = current_account.custom_surveys.default.first  
      redirect_to :id => default_survey.id, :action => :edit if(params[:id].to_i != default_survey.id)
    end

    def default_survey_feature_enabled?
      current_account.default_survey_enabled?
    end

    def load_survey
      @survey_id  = params[:id]
      @survey     = scoper.find_by_id(@survey_id)
      if @survey.nil?
        flash[:notice] = t(:'admin.surveys.survey_not_found')
        redirect_to admin_custom_surveys_path
      end
    end

    def validate_question_limit
      if (survey_questions_data.length - 1) > CustomSurvey::Survey::QUESTIONS_LIMIT
        render :json => {
          :error => t(:'admin.surveys.questions.limit_exceed_error', 
          :count => CustomSurvey::Survey::QUESTIONS_LIMIT)
        }
      end      
    end

    def check_survey_limit
      if scoper.length >= CustomSurvey::Survey::SURVEYS_LIMIT
        flash[:notice] = t(:'admin.surveys.limit_exceed_error', :count => CustomSurvey::Survey::SURVEYS_LIMIT)
        redirect_to admin_custom_surveys_path
      end
    end

    def update_questions survey_id
      survey_questions_data.each do |question|
        question['survey_id'] = survey_id
      end
    end

    def sorted_scoper
      scoper.sorted
    end

    def scoper
      current_account.custom_surveys.undeleted
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