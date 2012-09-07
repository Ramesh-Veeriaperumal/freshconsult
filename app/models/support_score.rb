class SupportScore < ActiveRecord::Base

  include Scoreboard::Constants  

  after_commit_on_destroy :update_agents_score
  after_commit_on_create  :update_agents_score

  belongs_to :user
  has_one :agent, :through => :user

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

  named_scope :customer_champion, {
    :conditions => { :score_trigger => [HAPPY_CUSTOMER, UNHAPPY_CUSTOMER] }
  }

  named_scope :group_score,
  { 
    :select => ["agent_groups.group_id, support_scores.*, SUM(support_scores.score) as tot_score"],
    #:joins => [:agent_groups],
    :joins => "INNER JOIN agent_groups on support_scores.user_id = agent_groups.user_id",
    :group => "agent_groups.group_id",
    :order => "tot_score desc"
  }

  named_scope :user_score,
  { 
    :select => ["support_scores.*, SUM(support_scores.score) as tot_score"],
    :include => [:user],
    :group => "user_id",
    :order => "tot_score desc"
  }

  named_scope :limit, lambda { |num| { :limit => num } } 

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
      :user_id => scorable.responder_id,
      :score => sb_rating.score,
      :score_trigger => sb_rating.resolution_speed
    }) if scorable.responder
  end

  def self.add_score(scorable, score, badge)    
    scorable.support_scores.create({      
      :user_id => scorable.user.id,
      :score => score,
      :score_trigger => TICKET_QUEST
    }) if scorable.user
  end

  def self.add_ticket_score(scorable, score, badge)
    scorable.support_scores.create({      
      :user_id => scorable.responder.id,
      :score => score,
      :score_trigger => TICKET_QUEST
    }) if scorable.responder
  end
  
protected
  
  def update_agents_score
      total_score = user.support_scores.sum(:score)
      unless (agent.points.eql? total_score)
        agent.update_attribute(:points, total_score)
      end
  end

end
