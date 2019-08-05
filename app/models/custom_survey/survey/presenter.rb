class CustomSurvey::Survey < ActiveRecord::Base
  include RepresentationHelper
  acts_as_api

  api_accessible :central_publish do |s|
    s.add :id
    s.add :account_id
    s.add :send_while_hash, as: :send_while
    s.add proc { |t| t.utc_format(t.created_at) }, as: :created_at
    s.add proc { |t| t.utc_format(t.updated_at) }, as: :updated_at
    s.add :title_text
    s.add :active
    s.add :thanks_text
    s.add :feedback_response_text
    s.add :can_comment
    s.add :comments_text
    s.add :default
    s.add :link_text
    s.add :happy_text
    s.add :neutral_text
    s.add :unhappy_text
    s.add :deleted
    s.add :good_to_bad
  end

  api_accessible :custom_translation do |survey|
    survey.add :title_text
    survey.add :comments_text
    survey.add :thanks_text
    survey.add :feedback_response_text
    survey.add proc { |sur| sur.fetch_default_questions_and_choices }, as: :default_question
    survey.add proc { |sur| sur.fetch_additional_questions_and_choices }, as: :additional_questions
  end

  def fetch_default_questions_and_choices
    default_question = {}
    question = fetched_survey_questions.find(&:default)
    default_question[:question] = question.label
    default_question[:choices] = question.choices.map { |choice| [choice[:face_value], choice[:value]] }.to_h
    default_question.stringify_keys
  end

  def fetch_additional_questions_and_choices
    additional_questions = {}
    questions = fetched_survey_questions.reject(&:default)
    return nil if questions.blank?

    questions.each do |question|
      additional_questions["question_#{question.id}".to_sym] = question.label
    end
    additional_questions[:choices] = questions.first.choices.map { |choice| [choice[:face_value], choice[:value]] }.to_h
    additional_questions.stringify_keys
  end

  # memoizing to avoid repeat db calls
  def fetched_survey_questions
    @fetched_survey_questions ||= survey_questions.preload(:custom_field_choices_asc, :custom_field_choices_desc, :survey)
  end

  def custom_translation_key
    "survey_#{id}"
  end
end