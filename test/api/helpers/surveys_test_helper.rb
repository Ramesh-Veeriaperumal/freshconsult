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

  def index_survey_pattern(surveys)
    pattern = []
    surveys.each do |survey|
      active_survey = active_classic_survey_rating(survey)
      if Account.current.new_survey_enabled?
        survey_questions = survey.survey_questions.map do |q|
          if q.default
            survey = { id: 'default_question', label: q.label, accepted_ratings: q.face_values, default: true }
          else
            survey = { id: "question_#{q.id}", label: q.label, accepted_ratings: q.face_values }
          end
          survey
        end
        active_survey.merge!(questions: survey_questions)
      end
      pattern << active_survey
    end
    pattern
  end

  def active_classic_survey_rating(survey)
    {
      id: survey.id,
      title: survey.title_text
    }
  end

  def create_survey(number, custom_survey = true)
    survey = @account.surveys.build(title_text: I18n.t('admin.surveys.new_layout.default_survey'),
                                    thanks_text: I18n.t('admin.surveys.new_thanks.thanks_feedback'),
                                    feedback_response_text: I18n.t('admin.surveys.new_thanks.feedback_response_text'),
                                    comments_text: I18n.t('admin.surveys.new_thanks.comments_feedback'),
                                    active: (@account.features?(:survey_links) ? true : false),
                                    can_comment: true,
                                    default: false)
    survey.save
    if custom_survey
      unhappy_text = survey.unhappy_text.blank? ? I18n.t('helpdesk.ticket_notifier.reply.unhappy') : survey.unhappy_text
      neutral_text = survey.neutral_text.blank? ? I18n.t('helpdesk.ticket_notifier.reply.neutral') : survey.neutral_text
      happy_text = survey.happy_text.blank? ? I18n.t('helpdesk.ticket_notifier.reply.happy') : survey.happy_text
      survey_question = CustomSurvey::SurveyQuestion.new(
        account_id: @account.id,
        name: 'default_survey_question',
        label: survey.link_text,
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

  def create_survey_result(ticket, rating, response_note = nil)
    old_rating = CustomSurvey::Survey.old_rating rating.to_i
    result = @account.custom_survey_results.build(account_id: @account,
                                                  survey_id: @account.survey.id,
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

  def ticket
    ticket = Helpdesk::Ticket.last || create_ticket(ticket_params_hash)
    ticket
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
end
