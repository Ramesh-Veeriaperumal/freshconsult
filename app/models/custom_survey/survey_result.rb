class CustomSurvey::SurveyResult < ActiveRecord::Base  

  self.primary_key = :id
  self.table_name = :survey_results

  include Va::Observer::Util
  
  concerned_with :associations

  after_create :update_observer_events, :update_ticket_rating
  after_commit :filter_observer_events, on: :create, :if => :user_present?

  # Survey result types 
  RATING = 1
  QUESTION = 2
  REMARKS = 3

  def custom_form
    survey # memcache this 
  end

  def custom_field_aliases

    @custom_field_aliases ||= custom_form.survey_questions.map(&:name)

  end
    
  def add_feedback(params)
    feedback = params[:feedback]
    if feedback.blank?
      feedback = I18n.t('support.surveys.feedback_not_given')
    end
    note = surveyable.notes.build({
      :user_id => customer_id,
      :note_body_attributes => {:body => Helpdesk::HTMLSanitizer.plain(feedback) },
      :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["feedback"],
      :incoming => true,
      :private => false
    })
    
    note.account_id = account_id
    note.save_note
    
    create_survey_remark({
      :account_id => account_id,
      :note_id => note.id
    })
    
    if params[:custom_field]
      update_attributes({:custom_field => params[:custom_field]})
      save!
    end         
  end

  def ticket_info
    question = survey.default_question
    value = survey_result_data[question.column_name]
    {  :value => value,
        :text => survey.rating_text(value),
        :label => question.label  }
  end

  def note_details
      {  :rating => rating , 
          :question_values => question_values , 
          :agent => agent.blank? ?  '' : agent.name , 
          :survey => survey.title_text  }
  end
  
  def rating
    self.survey_result_data[self.survey.default_question.column_name]
  end

  def happy?
    (rating == CustomSurvey::Survey::HAPPY || rating == CustomSurvey::Survey::VERY_HAPPY || rating == CustomSurvey::Survey::EXTREMELY_HAPPY)
  end

  def unhappy?
    (rating == CustomSurvey::Survey::UNHAPPY || rating == CustomSurvey::Survey::VERY_UNHAPPY || rating == CustomSurvey::Survey::EXTREMELY_UNHAPPY)
  end
  
  def get_small_img_class
        if happy?
           return "ficon-survey-happy"
        elsif unhappy?
           return "ficon-survey-sad"
        else
           return "ficon-survey-neutral"
        end
  end

  def text 
    return survey.rating_text(rating)
  end
                                                       
  def as_json(options={})
    options[:except] = [:account_id]
    super options
  end

  private

    def update_ticket_rating
      return unless surveyable.is_a? Helpdesk::Ticket

      surveyable.st_survey_rating= rating
      surveyable.survey_rating_updated_at= created_at
      surveyable.save
    end
    
    # VA - Observer Rule 
    def update_observer_events
      return unless surveyable.instance_of? Helpdesk::Ticket
      @model_changes = { :customer_feedback => rating }
    end   

    def question_values
        question_details = []
        survey.feedback_questions.each do |question|
          unless survey_result_data.blank?
            rating_value = survey_result_data[question.column_name]
            rating = {:label => question.label , 
                      :choices => question.choices}
              question.choices.each do |choice|
                if(choice[:face_value] == rating_value)
                    rating = rating.merge(:key => choice[:face_value], :value => choice[:value])
                    break
                end
              end
              question_details.push(rating) unless !rating.has_key?(:key)
          end
        end
        question_details
    end 
end