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

  def active_custom_survey_pattern(expected_output = {}, survey)
    active_survey = active_classic_survey_rating(expected_output, survey)
    if Account.current.new_survey_enabled?
      survey_questions = Account.current.survey.survey_questions.map do |q|
        if q.default
          survey = { id: 'default_question', label: q.label, accepted_ratings: q.face_values, default: true }
        else
          survey = { id: "question_#{q.id}", label: q.label, accepted_ratings: q.face_values }
        end
        survey
      end
      active_survey.merge!(questions: survey_questions)
    end
    active_survey
  end

  def active_classic_survey_rating(_expected_output = {}, survey)
    {
      id: survey.id,
      title: survey.title_text
    }
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
end
