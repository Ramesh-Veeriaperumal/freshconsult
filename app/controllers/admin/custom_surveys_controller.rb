class Admin::CustomSurveysController < Admin::AdminController

  helper AccountsHelper
  include Admin::CustomSurveysHelper

  before_filter { |c| current_account.new_survey_enabled? }
  before_filter :check_feature_for_toggle_setting, only: [:toggle_setting]
  before_filter :redirect_to_default_survey,          :if   => :default_survey_feature_enabled?
  around_filter :escape_html_entities_in_json
  before_filter :check_survey_limit,                  :only => [:new,    :create]
  before_filter :validate_csrf_token, only: [:create, :update, :toggle_setting]
  before_filter :validate_question_limit, only: [:create, :update]
  before_filter :load_survey,                         :only => [:edit,   :update, :destroy, :activate, :deactivate, :test_survey]
  before_filter :load_survey_statuses, only: [:edit], if: :multilingual_csat_enabled?
  before_filter :survey_translation_data, only: [:new, :edit], if: :multilingual_csat_enabled?
  before_filter :set_selected_tab, only: [:new, :edit], if: :multilingual_csat_enabled?
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
      cancelUrl:  current_account.default_survey_enabled? ? "/admin/home" : admin_custom_surveys_path,
      order: true
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
    first_survey_result = @survey.survey_results.first
    @layout_params = {
      action:       "update",
      method:       "put",
      active:       @survey.active?,
      default:      @survey.default?,
      title:        @survey.title_text,
      id:           @survey_id,
      url:          admin_custom_survey_path(@survey_id),
      cancelUrl:    current_account.default_survey_enabled? ? "/admin/home" : admin_custom_surveys_path,
      order:     @survey.good_to_bad?
    }
    @survey_details = {
      survey:               @survey.to_json({:except => :account_id}),
      survey_questions:     @survey.feedback_questions.to_json,
      default_question:     @survey.default_question.to_json,
      survey_result_exists: first_survey_result.present? 
    }
    flash[:notice] = t(:'admin.surveys.new_layout.result_exist_msg_v2') if !@survey.default? && first_survey_result.present?
                                                                         
  end  

  def update
    survey_was = @survey.as_api_response(:custom_translation).stringify_keys if update_survey_status? 
    if @survey.store(survey_data)
      update_questions @survey.id
      params[:jsonData] = survey_questions_data.to_json
      super
      @surveys = scoper
      update_survey_status(survey_was) if update_survey_status?
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

  def toggle_setting
    settings = params[:custom_survey]
    settings.each do |setting, enable|
      begin
        enable ? current_account.enable_setting(setting.to_sym) : current_account.disable_setting(setting.to_sym)
      rescue StandardError
        return render json: {
          error: t(:'errors.error_updating_setting')
        }, status: 400
      end
    end
    render json: {}
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

    def survey_translation_data
      @language_translations = {
        portal_languages: portal_languages_status,
        hidden_languages: hidden_languages_status
      }
    end

    def set_selected_tab
      @selected_tab = 'survey'
    end

    def load_survey_statuses
      @survey_statuses = @survey.custom_translations.select([:status, :language_id]).map { |a| [a.language_id, a.status] }.to_h
    end

    def survey_questions_data
      @survey_questions_data ||= JSON.parse(params[:jsonData])
    end

    def redirect_to_default_survey
      default_survey = current_account.custom_surveys.default.first  
      redirect_to :id => default_survey.id, :action => :edit if(params[:id].to_i != default_survey.id)
    end

    def check_feature_for_toggle_setting
      unless current_account.csat_email_scan_compatibility_settings_enabled?
        result_set = {}
        result_set['redirect_url'] = admin_custom_surveys_path
        result_set['error_message'] = t('flash.general.access_denied')
        render json: result_set
        flash[:error] = t('flash.general.access_denied')
      end
    end

    def default_survey_feature_enabled?
      current_account.default_survey_enabled?
    end

    def multilingual_csat_enabled?
      current_account.custom_translations_enabled?
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

    def update_survey_status?
      action_name.to_sym == :update && Account.current.custom_translations_enabled? && @errors.blank?
    end

    def update_survey_status(survey_was)
      Admin::CustomTranslations::UpdateSurveyStatus.perform_async({ :survey_was => survey_was , :survey_id => @survey.id})
    end

    def index_scoper
      @index_scoper || @survey.survey_questions.all
    end

    def validate_csrf_token
      csrf_token = request.headers['X-CSRF-Token']
      if csrf_token.blank? || csrf_token != session['_csrf_token']
        result_set = { surveys: @surveys.to_json }
        result_set['redirect_url'] = admin_custom_surveys_path
        result_set['error_message'] = t('flash.general.access_denied')
        render :json => result_set
        flash[:error] = t('flash.general.access_denied')
      end
    end
end
