class SupportScore < ActiveRecord::Base

  include Scoreboard::Constants  

  belongs_to :user, :class_name =>'User', :foreign_key =>'agent_id'

  belongs_to_account

  attr_protected  :account_id

  named_scope :created_at_inside, lambda { |start, stop|
    { :conditions => [" support_scores.created_at >= ? and support_scores.created_at <= ?", start, stop] }
  }

  named_scope :fast, { :conditions => 
        {:score_trigger => FAST_RESOLUTION }}

  named_scope :first_call, {
    :conditions => {:score_trigger => FIRST_CALL_RESOLUTION}}

  named_scope :happy_customer, {
    :conditions => {:score_trigger => HAPPY_CUSTOMER}}

  named_scope :unhappy_customer, {
    :conditions => {:score_trigger => UNHAPPY_CUSTOMER}}

  named_scope :total_score,
  { 
      :select => ["users.*, support_scores.*, SUM(support_scores.score) as tot_score"],
      :joins => [:user],
      :group => "users.id",
      :order => "tot_score desc"
  }

  def self.add_happy_customer(scorable)
    add_support_score(scorable, HAPPY_CUSTOMER)
  end

  def self.add_unhappy_customer(scorable)
    add_support_score(scorable, UNHAPPY_CUSTOMER)
  end
  
  def self.add_fcr_bonus_score(scorable)
    if (scorable.resolved_at  && scorable.ticket_states.inbound_count == 1)
      add_support_score(scorable, FIRST_CALL_RESOLUTION)
    end
  end 
  
  def self.add_support_score(scorable, resolution_speed)    
    sb_rating = scorable.account.scoreboard_ratings.find_by_resolution_speed(resolution_speed)
    scorable.support_scores.create({      
      :agent_id => scorable.responder_id,
      :score => sb_rating.score,
      :score_trigger => sb_rating.resolution_speed
    }) if scorable.responder
  end

  def self.add_score(scorable, score, badge)    
    scorable.support_scores.create({      
      :agent_id => scorable.user.id,
      :score => score,
      :score_trigger => 201
    }) if scorable.user
  end

  def self.add_ticket_score(scorable, score, badge)
    scorable.support_scores.create({      
      :agent_id => scorable.responder.id,
      :score => score,
      :score_trigger => 201
    }) if scorable.responder
  end
    
end
