class Survey < ActiveRecord::Base
  
  ANY_EMAIL_RESPONSE = 1
  RESOLVED_NOTIFICATION = 2
  
  belongs_to :account
  has_many :survey_points, :dependent => :destroy
  
  def can_send?(ticket, s_while)
    ticket.requester && ticket.requester.customer? && (send_while == s_while)
  end
end
