class SurveysController < ApiApplicationController
  include TicketConcern
  include Concerns::SurveyConcern

  def active_survey
    if custom_survey?
      @survey_questions = @item.survey_questions.map do |q|
        survey = { id: "question_#{q.id}", label: q.label, accepted_ratings: q.face_values }
        survey.merge!(default: true) if q.default
        survey
      end
    end
  end

  def scoper(item = @ticket)
    custom_survey? ? custom_survey_results(item) : classic_survey_results(item)
  end

  def custom_survey_results(item)
    item.custom_survey_results.preload({:survey => {survey_questions: :custom_field_choices}, :survey_result_data => { :custom_form => {}}, :survey_remark => {:feedback => { :note_old_body=> {}}}, :flexifield => {}}).order('created_at desc')
  end

  def classic_survey_results(item)
    item.survey_results.preload({ :survey_remark => {:feedback => { :note_old_body => {} }}}).order('created_at desc')
  end

  def custom_survey?
    @custom_survey ||= current_account.new_survey_enabled?
  end

  def load_object
    @item = current_account.survey
  end

  def load_ticket
    @ticket ||= current_account.tickets.where(display_id: params[:id]).first
    log_and_render_404 unless @ticket
    @ticket
  end

  def survey_results
    load_objects
    render "#{controller_path}/index"
  end

  def create
    if @item.save
      add_feedback if @feedback
      render_201
    else
      render_custom_errors
    end
  end

  def feature_name
    FeatureConstants::SURVEYS
  end

  def load_objects
    index? ? super(surveys_filter(scoper(current_account))) : super
  end

  private

    def validate_filter_params
      params.permit(*SurveyConstants::INDEX_FIELDS, *ApiConstants::DEFAULT_INDEX_FIELDS)
      @survey_filter = SurveyFilterValidation.new(params, nil, string_request_params?)
      render_errors(@survey_filter.errors, @survey_filter.error_options) unless @survey_filter.valid?
    end

    def surveys_filter(survey_results)
      @survey_filter.conditions.each do |key|
        clause = survey_results.survey_filter(@survey_filter)[key.to_sym] || {}
        survey_results = survey_results.where(clause[:conditions]).joins(clause[:joins])
      end
      survey_results
    end

    def add_feedback
      if custom_survey?
        @item.update_result_and_feedback(params)
      else
        @item.add_feedback(@feedback)
      end
    end

    def validate_params
      allowed_questions, allowed_default_choices, allowed_custom_choices = []
      fields = SurveyConstants::FIELDS
      if custom_survey?
        fields |= SurveyConstants::HASH_FIELDS
        construct_questions_hash
        allowed_questions = @question_id_name_mapping.empty? ? [nil] : @question_id_name_mapping.keys
        survey_questions = current_account.survey.survey_questions
        allowed_default_choices = survey_questions.first.face_values
        allowed_custom_choices = survey_questions.last.face_values if allowed_questions
        fields |= ['custom_ratings' => allowed_questions]
      end
      params[cname].permit(*(fields))
      survey = SurveyValidation.new(params[cname], @item, custom_survey?, allowed_custom_choices, allowed_default_choices)
      render_custom_errors(survey, true) unless survey.valid?
    end

    def sanitize_params
      # ForBackward compatibility converting rating to old rating and saving in class survey result where as custom_survey_result has custom rating
      if custom_survey?
        rating  = custom_rating(params[cname][:rating])
        params[cname][:rating] = CustomSurvey::Survey.old_rating rating.to_i
        params[cname]['custom_field'] = { "#{current_account.survey.default_question.name}" => rating }
        # converting Custom Rating hash keys from survey_question_id to survey_question_name
        params[cname]['custom_ratings'].each_pair { |key, value| params[cname]['custom_field'][@question_id_name_mapping[key]] = value } if params[cname]['custom_ratings'].present?
        params[cname].delete 'custom_ratings'
      end
      params[cname].merge!(survey_id: current_account.survey.id, customer_id: @ticket.requester_id, agent_id: @ticket.responder_id, group_id: @ticket.group_id)
      @feedback = params[cname].delete(:feedback)
    end

    def check_privilege
      return false unless super # break if there is no enough privilege.
      # load ticket and return 404 if ticket doesn't exists in case of APIs which has ticket_id in url
      return false if (create? || ticket_survey_result?) && !load_ticket
      verify_ticket_permission(api_current_user, @ticket) if @ticket
    end

    def construct_questions_hash
      @question_id_name_mapping = {}
      current_account.survey.survey_questions.feedback.each do |sq|
        @question_id_name_mapping["question_#{sq.id}"] = sq.name unless sq.default
      end
    end

    def ticket_survey_result?
      @ticket_survey_result ||= current_action?('survey_results')
    end

    def render_201(template_name: "#{controller_path}/#{action_name}")
      render template_name, status: 201
    end
end
