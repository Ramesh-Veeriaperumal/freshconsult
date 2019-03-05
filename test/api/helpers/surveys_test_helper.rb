['ticket_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module SurveysTestHelper
  include TicketHelper

  def survey_pattern(_expected_output = {}, survey)
    feedback = survey.survey_remark.feedback.body if survey.survey_remark
    {
      id: survey.id,
      survey_id: survey.survey_id,
      user_id: survey.customer_id,
      agent_id: survey.agent_id,
      group_id: survey.group_id,
      ticket_id: survey.surveyable.display_id,
      ratings: { default_questions: survey.rating },
      feedback: feedback,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def survey_custom_rating_pattern(expected_output = {}, survey)
    survey_result = survey_pattern(expected_output, survey)
    survey_result[:ratings] = survey.custom_ratings
    survey_result
  end

  def show_survey_pattern(survey, show_rating_labels = false)
    active_survey = active_classic_survey_rating(survey)
    if Account.current.new_survey_enabled?
      survey_questions = survey.survey_questions.map do |q|
        if q.default
          survey = { id: 'default_question', label: q.label, accepted_ratings: ratings(q, show_rating_labels), default: true }
        else
          survey = { id: "question_#{q.id}", label: q.label, accepted_ratings: ratings(q, show_rating_labels) }
        end
        survey
      end
      active_survey.merge!(questions: survey_questions)
    end
    active_survey
  end
  
  def index_survey_pattern(surveys, show_rating_labels = false)
    pattern = []
    surveys.each do |survey|
      pattern << show_survey_pattern(survey, show_rating_labels)
    end
    pattern
  end

  def ratings(question, show_labels = false)
    show_labels ? question.choices.map {|x| {label: x[:value], value: x[:face_value]}} : question.face_values
  end

  def active_classic_survey_rating(survey)
    {
      id: survey.id,
      title: survey.title_text,
      created_at: survey.created_at,
      updated_at: survey.updated_at
    }
  end

  def create_survey(number, custom_survey = true)
    survey = @account.surveys.build(title_text: I18n.t('admin.surveys.new_layout.default_survey'),
                                    thanks_text: I18n.t('admin.surveys.new_thanks.thanks_feedback'),
                                    feedback_response_text: I18n.t('admin.surveys.new_thanks.feedback_response_text'),
                                    comments_text: I18n.t('admin.surveys.new_thanks.comments_feedback'),
                                    active: (@account.features?(:survey_links) ? true : false),
                                    can_comment: true,
                                    default: false,
                                    send_while: 2)
    survey.save
    if custom_survey
      unhappy_text = survey.unhappy_text.blank? ? I18n.t('helpdesk.ticket_notifier.reply.unhappy') : survey.unhappy_text
      neutral_text = survey.neutral_text.blank? ? I18n.t('helpdesk.ticket_notifier.reply.neutral') : survey.neutral_text
      happy_text = survey.happy_text.blank? ? I18n.t('helpdesk.ticket_notifier.reply.happy') : survey.happy_text
      survey_question = CustomSurvey::SurveyQuestion.new(
        account_id: @account.id,
        name: 'default_survey_question',
        label: 'custom_survey_question_label',
        position: 1,
        survey_id: survey.id,
        field_type: :custom_survey_radio,
        default: true,
        custom_field_choices_attributes: [
          { position: 1, _destroy: 0, value: unhappy_text, face_value: CustomSurvey::Survey::EXTREMELY_UNHAPPY },
          { position: 2, _destroy: 0, value: neutral_text, face_value: CustomSurvey::Survey::NEUTRAL },
          { position: 3, _destroy: 0, value: happy_text, face_value: CustomSurvey::Survey::EXTREMELY_HAPPY }
        ]
      )
      survey_question.column_name = "cf_int0#{number}"
      survey_question.save
    end
  end

  def create_survey_result(ticket, rating, response_note = nil, survey_id = nil)
    old_rating = CustomSurvey::Survey.old_rating rating.to_i
    result = @account.custom_survey_results.build(account_id: @account,
                                                  survey_id: survey_id || @account.survey.id,
                                                  surveyable_id: ticket.id,
                                                  surveyable_type: 'Helpdesk::Ticket',
                                                  customer_id: ticket.requester_id,
                                                  agent_id: response_note ? response_note.user_id : ticket.responder_id,
                                                  group_id: ticket.group_id,
                                                  response_note_id: ticket,
                                                  custom_field: {
                                                    "#{@account.survey.default_question.name}" => rating
                                                  },
                                                  rating: old_rating)
    result.save
    result
  end

  def create_default_survey_result(ticket, rating, response_note = nil, survey_id = nil)
    result = @account.survey_results.build(account_id: @account,
                                           survey_id: survey_id || @account.survey.id,
                                           surveyable_id: ticket.id,
                                           surveyable_type: 'Helpdesk::Ticket',
                                           customer_id: ticket.requester_id,
                                           agent_id: response_note ? response_note.user_id : ticket.responder_id,
                                           group_id: ticket.group_id,
                                           response_note_id: ticket,
                                           rating: rating)
    result.save
    result
end

  def create_default_survey_result(ticket, rating, response_note = nil, survey_id = nil)
    result = @account.survey_results.build(account_id: @account,
                                           survey_id: survey_id || @account.survey.id,
                                           surveyable_id: ticket.id,
                                           surveyable_type: 'Helpdesk::Ticket',
                                           customer_id: ticket.requester_id,
                                           agent_id: response_note ? response_note.user_id : ticket.responder_id,
                                           group_id: ticket.group_id,
                                           response_note_id: ticket,
                                           rating: rating)
    result.save
    result
end

  def v1_survey_params
    { rating: 1,  feedback: Faker::Lorem.paragraph }
  end

  def v2_survey_params
    { ratings: { default_question: 103 },  feedback: Faker::Lorem.paragraph }
  end

  def v2_classic_survey_params
    { ratings: { default_question: 1 },  feedback: Faker::Lorem.paragraph }
  end

  def v2_classic_survey_payload
    v2_classic_survey_params.to_json
  end

  def v2_survey_payload
    v2_survey_params.to_json
  end

  def v1_survey_payload
    v1_survey_params.to_json
  end

  def stub_custom_survey(flag)
    @account.class.any_instance.stubs(:new_survey_enabled?).returns(flag)
  end

  def unstub_custom_survey
    @account.class.any_instance.unstub(:new_survey_enabled?)
  end

  def deactivate_survey
    if @account.new_survey_enabled?
      survey = @account.survey
      survey.active = 0
      survey.save
    else
      delete_survey_link_feature
    end
  end

  def delete_survey_link_feature
    @account.features.delete @account.features.survey_links
  end

  def create_survey_link_feature
    @account.features.survey_links.create
  end

  def activate_survey
    if @account.new_survey_enabled?
      survey = @account.survey
      survey.active = 1
      survey.save
    else
      create_survey_link_feature
    end
  end

  def central_survey_pattern(survey)
    {
      id: survey.id,
      account_id: survey.account_id,
      send_while: send_while_hash(survey.send_while),
      created_at: survey.created_at,
      updated_at: survey.updated_at,
      title_text: survey.title_text,
      active: survey.active,
      thanks_text: survey.thanks_text,
      feedback_response_text: survey.feedback_response_text,
      can_comment: survey.can_comment,
      comments_text: survey.comments_text,
      default: survey.default,
      link_text: survey.link_text,
      happy_text: survey.happy_text,
      neutral_text: survey.neutral_text,
      unhappy_text: survey.unhappy_text,
      deleted: survey.deleted,
      good_to_bad: survey.good_to_bad
    }
  end

  def send_while_hash(send_while)
    {
      id: send_while,
      type: Survey::SEND_WHILE_MAPPING[send_while]
    }
  end

  def survey_handle_questions_pattern(handle)
    survey_questions = handle.survey.survey_questions

    survey_questions.map do |question|
      {
        id: question.id,
        account_id: question.account_id,
        survey_id: question.survey_id,
        name: question.name,
        field_type: question.field_type,
        position: question.position,
        deleted: question.deleted,
        label: question.label,
        column_name: question.column_name,
        default: question.default,
        created_at: question.created_at,
        updated_at: question.updated_at
      }
    end
  end

  def surveyable_pattern(survey_assoc)
    {
      id: survey_assoc.surveyable_id,
      _model: survey_assoc.surveyable_type
    }
  end

  def survey_result_data_payload(result)
    survey_result_data = result.survey_result_data.reload
    survey_questions = result.survey_result_data.custom_fields_cache

    survey_questions.map do |question|
      face_value = survey_result_data.safe_send(question.column_name)
      result = { question_id: question.id, question: question.name }

      if face_value.present?
        choices = question.choices
        choice = choices.find { |c| c[:face_value] == face_value }[:name]
        result.merge!(choice: choice, choice_value: face_value, rating: old_rating(face_value))
      else
        result.merge!(choice: nil, choice_value: nil, rating: nil)
      end
      result
    end.compact
  end
end
