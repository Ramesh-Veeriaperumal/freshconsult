class CustomSurvey::Survey < ActiveRecord::Base

  self.primary_key = :id
  self.table_name = :surveys
  
  include Reports::ActivityReport
  include Cache::Memcache::Survey
  
  concerned_with :constants , :associations

  after_commit :clear_custom_survey_cache, :if => :active_survey_updated?

  xss_sanitize :only => [:link_text, :happy_text, :neutral_text , :unhappy_text , :title_text, :thanks_text , :feedback_response_text, :comments_text ], 
               :plain_sanitizer => [:link_text, :happy_text, :neutral_text , :unhappy_text ,:title_text, :thanks_text , :feedback_response_text, :comments_text ]

  def enable        
        self.update_attributes(:active => true)
        self.save!
  end
  
  def disable
        self.update_attributes(:active => false)
        self.save!
  end

  def default_question
    survey_questions.where({:default => true}).first
  end

  def feedback_questions
    survey_questions.where({:default => false})
  end

  def can_send?(ticket, s_while)
    ( account.features?(:surveys, :survey_links) && ticket.requester && 
           ticket.requester.customer? && ((send_while == s_while) || s_while == PLACE_HOLDER) )
  end

  def self.old_rating rating
    if ( rating == EXTREMELY_HAPPY ||  rating == VERY_HAPPY || rating == HAPPY )
      rating = ::Survey::HAPPY
    elsif ( rating == EXTREMELY_UNHAPPY ||  rating == VERY_UNHAPPY || rating == UNHAPPY )
      rating = ::Survey::UNHAPPY
    elsif rating ==  NEUTRAL
      rating = ::Survey::NEUTRAL
    end
    rating
  end

  def store(params)
    survey = JSON.parse params[:survey]
    self.send_while = survey["send_while"]
    self.title_text = survey["title_text"].blank? ? 
                            I18n.t('admin.surveys.new_layout.default_survey') :
                            survey["title_text"]
    self.active = survey["active"] || false
    self.can_comment = survey["can_comment"]
    self.thanks_text = survey["thanks_text"].blank? ? 
                                 I18n.t('admin.surveys.thanks_contents.message_text') :
                                 survey["thanks_text"]
    self.feedback_response_text = survey["feedback_response_text"].blank? ? 
                                                    I18n.t('admin.surveys.new_thanks.thanks_feedback') 
                                                    : survey["feedback_response_text"]
    self.comments_text = survey["comments_text"].blank? ?
                                       I18n.t('admin.surveys.new_thanks.comments_feedback') :
                                       survey["comments_text"]
    @choices = JSON.parse(survey["choices"])
    save!
    
    default_choices = []
    @choices.each_with_index{ |c,index| default_choices << { :position => (index+1), :_destroy => 0, :value => c[0], :face_value => c[1] } }
    
    default_question_format = { 
                                    :type =>"survey_radio",
                                     :field_type => "custom_survey_radio",
                                     :label => survey["link_text"].blank? ? 
                                                I18n.t('admin.surveys.satisfaction_settings.link_text_input_label') :
                                                survey["link_text"],
                                      :id => nil,
                                     :survey_id => self.id,
                                     :action =>"create",
                                     :default => true,
                                     :custom_field_choices_attributes => default_choices,
                                     :position => 1
                                 }
  
    unless default_question.blank?
      default_question_format[:id] = default_question.id 
      default_question_format[:action] = "update"
      default_question_format[:custom_field_choices_attributes] = regenerate_choices default_question, default_choices
    end
    
    if params[:jsonData]
       questions = [default_question_format]
       jsonData = JSON.parse params[:jsonData]
       jsonData.each do |question|
          question["survey_id"] = self.id if question["id"].blank?
          question["default"] = false
          unless question["id"].blank?
            survey_question = survey_questions.find(question["id"])
            question["custom_field_choices_attributes"] = regenerate_choices survey_question, question["custom_field_choices_attributes"]
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
        return @choices.each    { |c| [c[0], c[1]] } unless @choices.nil?
        default_question.custom_field_choices.to_json unless default_question.blank?
  end

  def self.satisfaction_survey_html(ticket)
    survey_handle = CustomSurvey::SurveyHandle.create_handle_for_place_holder(ticket)
    CustomSurveyHelper.render_content_for_placeholder({ :ticket => ticket, 
                                     :survey_handle => survey_handle, 
                                     :surveymonkey_survey => nil})
  end

  def choice_names
    default_question.custom_field_choices.collect{|c| [c.face_value, c.value]}
  end

  def rating_text(rating)
    default_question.custom_field_choices.each do |pick|
      if pick.face_value == rating
        return pick.value
      end
    end
  end

  def self.sample_ticket(user,id)
    sample_ticket_message = I18n.t('support.tickets.ticket_survey.survey_preview_ticket_message')
    ticket = Helpdesk::Ticket.new
    ticket.subject = I18n.t('support.tickets.ticket_survey.subject' , :title => self.find(id).title_text) 
    ticket.description_html = sample_ticket_message
    ticket.requester = user
    #build ticket and sanitize is not required for test mail
    ticket.save!
    ticket
  end

  def title(rating)        
        if rating==CUSTOMER_RATINGS[HAPPY]
           self.happy_text.downcase
        elsif rating==CUSTOMER_RATINGS[UNHAPPY]
           self.unhappy_text.downcase
        else
           self.neutral_text.downcase
        end
  end

  private

  def regenerate_choices question,choices
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
end