class CustomSurvey::Survey < ActiveRecord::Base
  self.primary_key = :id
  self.table_name = :surveys
  
  include Reports::ActivityReport
  include Cache::Memcache::Survey
  
  concerned_with :constants, :associations
  attr_protected :account_id, :active, :default, :deleted

  after_commit :clear_custom_survey_cache, :if => :active_survey_updated?

  xss_sanitize :only => [:link_text, :happy_text, :neutral_text , :unhappy_text , :title_text, :thanks_text , :feedback_response_text, :comments_text ], 
               :plain_sanitizer => [:link_text, :happy_text, :neutral_text , :unhappy_text ,:title_text, :thanks_text , :feedback_response_text, :comments_text ]

  def activate
    ActiveRecord::Base.transaction do
      Account.current.custom_surveys.deactivate_active_surveys  
      self.active = true
      save ? true : (raise ActiveRecord::Rollback)
    end
  end

  def self.deactivate_active_surveys
    active.each &:deactivate #though there will be just one active survey
  end
  
  def deactivate
    self.active = false
    save
  end

  def default_question #this way no need to memoize & in most cases all survey_questions are fetched
    survey_questions.find &:default
  end

  def feedback_questions
    survey_questions.reject &:default
  end

  def can_send?(ticket, s_while)
    (Account.current.new_survey_enabled? && Account.current.active_custom_survey_from_cache.present? && 
      ticket.requester && ticket.requester.customer? && 
        ((send_while == s_while) || s_while == PLACE_HOLDER))
  end

  def store(survey_data)
    self.attributes = survey_data
    self.active = false unless survey_data[:active] #setting default here, activate/deactivate will go via a diff flow
    save
  end

  def choices=(c_attr)
    @choices = c_attr
  end

  def choices(model = nil)
    if !@choices.nil?
      @choices.each { |c| [c[0], c[1]] }
    elsif !default_question.blank?      
      default_question.custom_field_choices.to_json
    end
  end

  def choice_names
    default_question.custom_field_choices.collect{|c| [c.face_value, c.value]}
  end

  def self.old_rating(rating)
    if (rating == EXTREMELY_HAPPY || rating == VERY_HAPPY || rating == HAPPY)
      ::Survey::HAPPY
    elsif (rating == EXTREMELY_UNHAPPY ||  rating == VERY_UNHAPPY || rating == UNHAPPY)
      ::Survey::UNHAPPY
    elsif rating ==  NEUTRAL
      ::Survey::NEUTRAL
    end
  end

  def rating_text(rating)
    choice = default_question.custom_field_choices.find{ |pick| pick.face_value == rating }
    choice.value unless choice.nil?
  end

  def title(rating)        
    if rating == CUSTOMER_RATINGS[HAPPY]
      self.happy_text.downcase
    elsif rating == CUSTOMER_RATINGS[UNHAPPY]
      self.unhappy_text.downcase
    else
      self.neutral_text.downcase
    end
  end

  def self.satisfaction_survey_html(ticket)
    survey_handle = CustomSurvey::SurveyHandle.create_handle_for_place_holder(ticket)
    CustomSurveyHelper.render_content_for_placeholder({ 
      :ticket => ticket, 
      :survey_handle => survey_handle, 
      :surveymonkey_survey => nil
    })
  end

  def sort_string
    "#{!deleted}_#{active}_#{updated_at.to_i}"
  end

  def self.sorted
    all.sort{ |a,b| b.sort_string <=> a.sort_string }
  end

  def self.as_reports_json
   {:deleted => deleted.sorted.map{ |survey| survey.as_reports_json},
    :undeleted => undeleted.sorted.map{ |survey| survey.as_reports_json}}
  end

  def as_reports_json
    options = {
      :only     => [:id, :title_text, :choices, :link_text, :active, :deleted, :created_at, :can_comment, :good_to_bad],
      :methods  => :choices,
      :include  => {
        :survey_questions => {
          :only     => [:id, :name, :label, :default], 
          :methods  => :choices}}
    }
    as_json(options)['survey']
  end
end