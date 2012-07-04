class Survey < ActiveRecord::Base
  
  include Reports::ActivityReport
  
  ANY_EMAIL_RESPONSE = 1
  RESOLVED_NOTIFICATION = 2
  CLOSED_NOTIFICATION = 3
  SPECIFIC_EMAIL_RESPONSE = 4
  PLACE_HOLDER = 5

  #customer rating
  HAPPY = 1
  NEUTRAL = 2
  UNHAPPY = 3
  
  CUSTOMER_RATINGS = {
    HAPPY => 'happy',
    NEUTRAL => 'neutral',
    UNHAPPY => 'unhappy'
  }
  
  CUSTOMER_RATINGS_BY_TOKEN = CUSTOMER_RATINGS.invert
  
  FILTER_BY_ARR = [["By Agents" , :agent] , ["By Groups", :group] , ["Overall Helpdesk" , :company]]

  AGENT = "agent"
  GROUP = "group"
  OVERALL = "company"

  LIST = "list"
  
  belongs_to :account
  has_many :survey_handles, :dependent => :destroy
  has_many :survey_results, :dependent => :destroy
  
  def can_send?(ticket, s_while)    
    ( account.features?(:surveys, :survey_links) && ticket.requester && 
           ticket.requester.customer? && ((send_while == s_while) || s_while == PLACE_HOLDER) )
  end
  
  def store(survey)
    self.send_while = survey[:send_while]
    self.link_text = survey[:link_text]
    self.happy_text = survey[:happy_text]
    self.neutral_text = survey[:neutral_text]
    self.unhappy_text = survey[:unhappy_text]
    save
  end
 
  def self.satisfaction_survey_html(ticket)
        
        survey_handle = SurveyHandle.create_handle_for_place_holder(ticket)
        
        ActionController::Base.helpers.render(:partial => "app/views/helpdesk/ticket_notifier/satisfaction_survey.html.erb",
                                                                    :locals => {:ticket => ticket, :survey_handle => survey_handle})
  end

end