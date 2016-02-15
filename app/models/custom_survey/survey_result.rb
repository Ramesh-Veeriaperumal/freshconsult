class CustomSurvey::SurveyResult < ActiveRecord::Base  
  self.primary_key = :id
  self.table_name = :survey_results

  include Va::Observer::Util
  
  concerned_with :associations, :callbacks

  # Survey result types 
  RATING    = 1
  QUESTION  = 2
  REMARKS   = 3

  RATING_ALL_URL_REF = 'r' #used in a scope

  def custom_form
    survey # memcache this 
  end

  def custom_field_aliases
    @custom_field_aliases ||= custom_form.survey_questions.map(&:name)
  end
    
  def update_result_and_feedback(params)
    feedback = survey_remark.feedback
    feedback_text = Helpdesk::HTMLSanitizer.plain(params[:feedback])
    feedback.attributes = {
      :note_body_attributes => {
        :body       => feedback_text, 
        :body_html  => "<div>#{feedback_text}</div>"
      }
    }
    feedback.save_note!
    update_attributes({:custom_field => params[:custom_field]}) if params[:custom_field]
  end

  def ticket_info
    default_question = survey.default_question
    value = survey_result_data[default_question.column_name]
    { 
      :value  => value,
      :text   => survey.rating_text(value),
      :label  => default_question.label 
    }
  end

  def note_details
    { 
      :rating           => rating, 
      :question_values  => question_values, 
      :agent            => agent.blank? ?  '' : agent.name, 
      :survey           => survey.title_text 
    }
  end
  
  def rating
    survey_result_data[default_question_column_name]
  end

  def default_question_column_name #to avoid N+1 queries
    :cf_int01
  end

  def happy?
    (rating == CustomSurvey::Survey::HAPPY || rating == CustomSurvey::Survey::VERY_HAPPY || rating == CustomSurvey::Survey::EXTREMELY_HAPPY)
  end

  def unhappy?
    (rating == CustomSurvey::Survey::UNHAPPY || rating == CustomSurvey::Survey::VERY_UNHAPPY || rating == CustomSurvey::Survey::EXTREMELY_UNHAPPY)
  end
  
  def get_small_img_class
    if happy?
      "ficon-survey-happy"
    elsif unhappy?
      "ficon-survey-sad"
    else
      "ficon-survey-neutral"
    end
  end

  def text 
    survey.rating_text(rating)
  end

  def as_json(options={})
    options[:except] = [:account_id]
    super options
  end

  def self.remarks_json question_column
    {:remarks => all.map{ |remark| remark.remarks_json question_column }}
  end

  def remarks_json question_column
    options = { 
      :only     => [:id, :created_at],
      :include  => { 
        :survey_remark => { 
          :include => {
            :feedback => {:only => [:body]}
          }
        },
        :surveyable => {:only => [:display_id, :subject]},
        :customer   => {:only => [:id, :name]},
        :agent      => {:only => [:name]},
        :group      => {:only => [:name]}
      }
    }
    json = as_json(options)['survey_result']
    json[:customer][:avatar] = customer.avatar_url
    json[:survey_remark] ||= {"feedback" => {"body" => ''}}
    json[:rating] = question_rating question_column
    json
  end

  private

    def question_rating question_column
      survey_result_data[question_column]
    end

    def question_values
      survey.feedback_questions.inject([]) do |question_details, question|
        rating_value = survey_result_data[question.column_name]
        choice = question.choices.find{ |choice| choice[:face_value] == rating_value }  
        if choice.present?
          rating = {
            :label    => question.label, 
            :choices  => question.choices,
            :key      => choice[:face_value], 
            :value    => choice[:value]
          }
          question_details.push(rating) 
        else
          question_details
        end
      end
    end 
end