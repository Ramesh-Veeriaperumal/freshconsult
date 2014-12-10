class SupportScore < ActiveRecord::Base

  self.primary_key = :id
  include Gamification::Scoreboard::Constants
  

  #https://github.com/rails/rails/issues/988#issuecomment-31621550
  after_commit ->(obj) { obj.update_agents_score }, on: :create
  after_commit ->(obj) { obj.update_agents_score }, on: :destroy

  belongs_to :user
  has_one :agent, :through => :user

  belongs_to :group

  belongs_to_account

  attr_protected  :account_id

  scope :created_at_inside, lambda { |start, stop| where(" support_scores.created_at >= ? and support_scores.created_at <= ?", start, stop) }

 scope :fast, -> { where(:score_trigger => FAST_RESOLUTION)} 

  scope :first_call, -> { where(:score_trigger => FIRST_CALL_RESOLUTION) }

  scope :happy_customer, -> { where(:score_trigger => HAPPY_CUSTOMER ) }

  scope :unhappy_customer, -> { where( :score_trigger => UNHAPPY_CUSTOMER ) }

  scope :customer_champion, -> { where( :score_trigger => [HAPPY_CUSTOMER, UNHAPPY_CUSTOMER] ) }
  
  scope :by_performance, -> { where("score_trigger != ?", AGENT_LEVEL_UP) }

  scope :group_score, -> { select("support_scores.*, SUM(support_scores.score) as tot_score, MAX(support_scores.created_at) as recent_created_at").
      joins("INNER JOIN groups ON groups.id = support_scores.group_id and groups.account_id = support_scores.account_id").where("group_id is not null and groups.id is not null").
      group("group_id").order("tot_score desc, recent_created_at")
  }
  
  scope :user_score, lambda { |query|
    {
    :select => ["support_scores.*, SUM(support_scores.score) as tot_score, MAX(support_scores.created_at) as recent_created_at"],
    :conditions => query[:conditions],
    :include => { :user => [ :avatar ] },
    :group => "user_id",
    :order => "tot_score desc, recent_created_at"
    }
  }
  
  # RAILS3 by default has this feature
  #scope :limit, lambda { |num| { :limit => num } } 

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
      :group_id => scorable.group_id,
      :score => sb_rating.score,
      :score_trigger => sb_rating.resolution_speed
    }) if scorable.responder
  end

  def self.add_agent_levelup_score(scorable, score)
    scorable.support_scores.create({
      :user_id => scorable.id,
      :score => score,
      :score_trigger => AGENT_LEVEL_UP
    }) if scorable
  end

protected
  
  def update_agents_score
    Resque.enqueue(Gamification::Scoreboard::UpdateUserScore, { :id => user.id, 
                    :account_id => user.account_id })
  end

end
