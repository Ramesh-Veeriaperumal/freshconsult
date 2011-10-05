class SupportScore < ActiveRecord::Base
  #Score triggers
  TICKET_CLOSURE = 1
  SURVEY_FEEDBACK = 2
  
  SCORE_TRIGGERS = { ScoreboardRating::HAPPY_CUSTOMER => SURVEY_FEEDBACK }
  
  def self.happy_customer(scorable)
    add_support_score(scorable, ScoreboardRating::HAPPY_CUSTOMER)
  end
  
  def self.add_support_score(scorable, resolution_speed)
    sb_rating = scorable.account.scoreboard_ratings.find_by_resolution_speed(resolution_speed)
    
    scorable.support_scores.create({
      :account_id => scorable.account_id,
      :agent_id => scorable.responder_id,
      :score => sb_rating.score,
      :score_trigger => SCORE_TRIGGERS.fetch(resolution_speed, TICKET_CLOSURE)
    }) if scorable.responder
  end
end
