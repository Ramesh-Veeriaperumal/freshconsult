class SupportScore < ActiveRecord::Base
  #Score triggers
  TICKET_CLOSURE = 1
  SURVEY_FEEDBACK = 2
  
  SCORE_TRIGGERS = { ScoreboardRating::HAPPY_CUSTOMER => SURVEY_FEEDBACK }

  belongs_to :user, :class_name =>'User', :foreign_key =>'agent_id'

  named_scope :created_at_inside, lambda { |start, stop|
    { :conditions => [" support_scores.created_at >= ? and support_scores.created_at <= ?", start, stop] }
  } 

  named_scope :fastcall_resolution, {
    :conditions => ["#{SupportScore.table_name}.score_trigger = ?", ScoreboardRating::FAST_RESOLUTION]
  }

  named_scope :ontime_resolution, {
    :conditions => ["#{SupportScore.table_name}.score_trigger = ?", ScoreboardRating::ON_TIME_RESOLUTION]
  }

  named_scope :late_resolution, {
    :conditions => ["#{SupportScore.table_name}.score_trigger = ?", ScoreboardRating::LATE_RESOLUTION]
  }

  named_scope :happycustomer_resolution, {
    :conditions => ["#{SupportScore.table_name}.score_trigger = ?", ScoreboardRating::HAPPY_CUSTOMER]
  }

  named_scope :support_scores_all,
  { 
      :select => ["users.*, support_scores.*, SUM(#{SupportScore.table_name}.score) as tot_score"],
      :joins => [:user],
      :group => "#{User.table_name}.id",
      :order => "SUM(#{SupportScore.table_name}.score) desc"
  }

  def self.happy_customer(scorable)
    add_support_score(scorable, ScoreboardRating::HAPPY_CUSTOMER)
  end
  
  def self.add_support_score(scorable, resolution_speed)
    sb_rating = scorable.account.scoreboard_ratings.find_by_resolution_speed(resolution_speed)
    
    scorable.support_scores.create({
      :account_id => scorable.account_id,
      :agent_id => scorable.responder_id,
      :score => sb_rating.score,
      :score_trigger => sb_rating.resolution_speed #SCORE_TRIGGERS.fetch(resolution_speed, TICKET_CLOSURE)
    }) if scorable.responder
  end
end
