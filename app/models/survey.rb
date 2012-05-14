class Survey < ActiveRecord::Base
  
  include Reports::ActivityReport
  
  ANY_EMAIL_RESPONSE = 1
  RESOLVED_NOTIFICATION = 2
  
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
  
  FILTER_BY_ARR = [["Agents" , :agent] , ["Group", :group] , ["Company" , :company]]
  
  belongs_to :account
  has_many :survey_handles, :dependent => :destroy
  has_many :survey_results, :dependent => :destroy
  
  def can_send?(ticket, s_while)
    ( account.features?(:surveys, :survey_links) && ticket.requester && 
           ticket.requester.customer? && (send_while == s_while) )
  end
  
  def store(survey)     
    self.send_while = survey[:send_while]
    self.link_text = survey[:link_text]
    save
  end    
   
end
