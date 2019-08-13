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

  api_accessible :custom_translation_secondary do |survey|
    survey.add ->(model, options) { model.translation(options[:lang])['title_text'] || '' }, as: :title_text
    survey.add ->(model, options) { model.translation(options[:lang])['comments_text'] || '' }, as: :comments_text
    survey.add ->(model, options) { model.translation(options[:lang])['thanks_text'] || '' }, as: :thanks_text
    survey.add ->(model, options) { model.translation(options[:lang])['feedback_response_text'] || '' }, as: :feedback_response_text
    survey.add ->(model, options) { model.fetch_default_questions_and_choices(options[:lang]) }, as: :default_question
    survey.add ->(model, options) { model.fetch_additional_questions_and_choices(options[:lang]) }, as: :additional_questions
  end

  def fetch_default_questions_and_choices(lang = nil)
    default_question = {}
    question = fetch_survey_questions.find(&:default)
    default_question['question'] = lang.blank? ? question.label : (translation(lang)['default_question'] || {})['question'] || ''
    default_question['choices'] = fetch_choices_translation(question, lang, 'default_question')
    default_question
  end

  def fetch_additional_questions_and_choices(lang = nil)
    additional_questions = {}
    questions = fetch_survey_questions.reject(&:default)
    return nil if questions.blank?

    questions.each do |question|
      additional_questions["question_#{question.id}"] = lang.blank? ? question.label : (translation(lang)['additional_questions'] || {})["question_#{question.id}"] || ''
    end
    additional_questions['choices'] = fetch_choices_translation(questions.first, lang, 'additional_questions')
    additional_questions
  end

  def fetch_choices_translation(question, lang = nil, type = nil)
    choice_translation = {}
    question.choices.each do |choice|
      choice_translation[choice[:face_value]] = lang.blank? ? choice[:value] : ((translation(lang)[type] || {})['choices'] || {})[choice[:face_value]] || ''
    end
    choice_translation
  end

  def fetch_survey_questions
    @fetch_survey_questions ||= survey_questions.preload(:custom_field_choices_asc, :custom_field_choices_desc, :survey)
  end

  def translation(lang)
    @translation ||= (safe_send("#{lang.underscore}_translation").try(:translations) || {})
  end

  def custom_translation_key
    "survey_#{id}"
  end
end
