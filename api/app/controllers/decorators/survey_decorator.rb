class SurveyDecorator < ApiDecorator
  delegate :id, :title_text, :survey_questions, to: :record

  def initialize(record, options)
    super(record)
    @custom_survey = options[:custom_survey]
  end

  def custom_survey?
    @custom_survey
  end

  def questions
    survey_questions.map do |q|
      survey = { id: "question_#{q.id}", label: q.label, accepted_ratings: q.face_values }
      survey.merge!(default: true, id: 'default_question') if q.default
      survey
    end
  end
end
