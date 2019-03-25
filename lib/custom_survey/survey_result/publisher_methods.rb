module CustomSurvey::SurveyResult::PublisherMethods
  HAPPY_RATING = [CustomSurvey::Survey::EXTREMELY_HAPPY, CustomSurvey::Survey::VERY_HAPPY, CustomSurvey::Survey::HAPPY].freeze
  UNHAPPY_RATING = [CustomSurvey::Survey::EXTREMELY_UNHAPPY, CustomSurvey::Survey::VERY_UNHAPPY, CustomSurvey::Survey::UNHAPPY].freeze
  NEUTRAL_RATING = [CustomSurvey::Survey::NEUTRAL].freeze

  def survey_result_data_payload(include_unanswered = false)
    survey_result_data = self.survey_result_data.reload
    survey_questions = self.survey_result_data.custom_fields_cache

    survey_questions.map do |question|
      face_value = survey_result_data.safe_send(question.column_name)
      next unless face_value.present? || include_unanswered
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

  def old_rating(rating)
    if HAPPY_RATING.include? rating
      ::Survey::HAPPY
    elsif UNHAPPY_RATING.include? rating
      ::Survey::UNHAPPY
    elsif NEUTRAL_RATING.include? rating
      ::Survey::NEUTRAL
    end
  end
end
