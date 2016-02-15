class CustomSurvey::Survey < ActiveRecord::Base
  self.primary_key = :id
  self.table_name = :surveys
  
  include Reports::ActivityReport
  include Cache::Memcache::Survey
  
  concerned_with :constants, :associations
  attr_protected :account_id, :active, :default

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
    survey_questions[0]
  end

  def feedback_questions
    survey_questions[1..-1]
  end

  def can_send?(ticket, s_while)
    (Account.current.new_survey_enabled? && Account.current.active_custom_survey_from_cache.present? && 
      ticket.requester && ticket.requester.customer? && 
        ((send_while == s_while) || s_while == PLACE_HOLDER))
  end

  def store(params)
    survey = JSON.parse(params[:survey])

    ["send_while", "title_text", "can_comment", "thanks_text", "feedback_response_text", "comments_text"].each do |param|
      value = (survey[param].blank? and DEFAULT_TEXT[param]) ? I18n.t(DEFAULT_TEXT[param]) : survey[param]
      self.send("#{param}=", value)
    end
    self.active = false unless survey["active"] #setting default here, activate/deactivate will go via a diff flow
    @choices = survey["choices"]
    return false unless save

    default_choices = @choices.each_with_index.inject([]) do |result, (c, index)|
      result << { 
        :position   => (index+1), 
        :_destroy   => 0, 
        :value      => c[0], 
        :face_value => c[1] 
      }
    end
    
    if params[:jsonData]
      questions  = [formatted_default_question(default_choices, survey["link_text"])]
      jsonData   = JSON.parse params[:jsonData]
      jsonData.each do |question|
        question["survey_id"] = self.id if question["id"].blank?
        question["default"] = false
        unless question["id"].blank?
          survey_question = survey_questions.find(question["id"])
          question["custom_field_choices_attributes"] = regenerate_choices(survey_question, question["custom_field_choices_attributes"])
        end
        questions << question
      end
    end
    params[:jsonData] = questions.to_json.to_s
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
    if (rating == EXTREMELY_HAPPY ||  rating == VERY_HAPPY || rating == HAPPY)
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

  def self.sample_ticket(user, id)
    sample_ticket_message = I18n.t('support.tickets.ticket_survey.survey_preview_ticket_message')
    Account.current.tickets.create(
      :subject => I18n.t('support.tickets.ticket_survey.subject', :title => self.find(id).title_text),
      :ticket_body_attributes =>  {
        :description => sample_ticket_message,
        :description_html => "<div>#{sample_ticket_message}</div>",
      },
      :requester => user
    )
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

  def self.as_reports_json
    all.map{ |survey| survey.as_reports_json }
  end

  def as_reports_json
    options = {
      :only     => [:id, :title_text, :choices, :link_text, :active, :created_at, :can_comment],
      :methods  => :choices,
      :include  => {
        :survey_questions => {
          :only     => [:id, :name, :label, :default], 
          :methods  => :choices}}
    }
    as_json(options)['survey']
  end

  private

    def regenerate_choices(question, choices)
      question_choices = question.choices
      if choices.length == question_choices.length
        choices.each_with_index do |c,index|
          choices[index] = choices[index].inject({}){|item,(k,v)| item[k.to_sym] = v; item}
          choices[index].reverse_merge!(question_choices[index])
        end
      else
        removable_choices = []
        question_choices.each do |choice|
          choice = choice.inject({}){|item,(k,v)| item[k.to_sym] = v; item}
          removable_choices << choice.merge({:_destroy => true})
        end
        choices = removable_choices + choices
      end
      choices
    end

    def formatted_default_question(default_choices, link_text)
      question_format = { 
        :type       =>  "survey_radio",
        :field_type =>  "custom_survey_radio",
        :label      =>  link_text.blank? ? I18n.t(DEFAULT_TEXT["link_text"]) : link_text,
        :id         =>  nil,
        :survey_id  =>  self.id,
        :action     =>  "create",
        :default    =>  true,      
        :position   =>  1,
        :custom_field_choices_attributes => default_choices
      }
    
      unless default_question.blank?
        question_format.merge!({
          :id     => default_question.id,
          :action => "update",
          :custom_field_choices_attributes => regenerate_choices(default_question, default_choices)
        })
      end
      question_format
    end
end