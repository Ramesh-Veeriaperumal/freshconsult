class GamificationQuestsObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket, Solution::Article, Solution::ArticleMeta, Topic, Post, SurveyResult, CustomSurvey::SurveyResult

  include Redis::RedisKeys
  include Redis::OthersRedis
	include Gamification::GamificationUtil

	SOLUTION_UPDATE_ATTRIBUTES = ["status"]
	SOLUTION_META_UPDATE_ATTRIBUTES = ["solution_folder_meta_id"]
	TOPIC_UPDATE_ATTRIBUTES = ["forum_id", "user_votes"]
  
  def after_commit(model)
    if model.send(:transaction_include_action?, :create)
      commit_on_create(model)
    elsif model.send(:transaction_include_action?, :update)
      commit_on_update(model) 
    end
    true
  end
  
  private
  
	def commit_on_create(model)
		return unless gamification_feature?(model.account) && (model.class.name.to_sym != :"Solution::ArticleMeta")
		process_quests(model)
	end

	def commit_on_update(model)
		return unless (!([:Post,:SurveyResult,:"CustomSurvey::SurveyResult"].include? model.class.name.to_sym) and gamification_feature?(model.account))
		process_quests(model)
	end

	def process_quests(model)
		send("process_#{model_name(model)}_quests", model)
		rollback_achieved_quests(model) if :"Helpdesk::Ticket".eql? model.class.name.to_sym
		
	end

	def process_ticket_quests(ticket)
    if ticket.responder and ticket.resolved_now?
      queue_quest_calculation(ticket)
    end
  end

  def rollback_achieved_quests(ticket)
    if ticket.responder and ticket.reopened_now?

      # Check if quest performance optimization is enabled for the account
      if Account.current.launched?(:gamification_quest_perf)
        # Enqueueing is done in 30 minutes because the quest processing would 
        # be queued in a maximum of 30 minutes
        Gamification::ProcessTicketQuests.perform_in(5.minute.from_now, { :id => ticket.id, :account_id => ticket.account_id, :rollback => true, :resolved_time_was => ticket.ticket_states.resolved_time_was })
      else
        # if not proceed as usual
        Resque.enqueue(Gamification::Quests::ProcessTicketQuests, {
          :id => ticket.id,:account_id => ticket.account_id, :rollback => true,
          :resolved_time_was => ticket.ticket_states.resolved_time_was })
      end
    end
  end

  def process_article_quests(article)
  	changed_article_attributes = article.article_changes.keys & SOLUTION_UPDATE_ATTRIBUTES
  	if changed_article_attributes.any? and article.published?
  		Resque.enqueue(Gamification::Quests::ProcessSolutionQuests, { :id => article.id, 
				:account_id => article.account_id })
  	end
  end
	
  def process_article_meta_quests(article_meta)
  	if article_meta.previous_changes.keys & SOLUTION_META_UPDATE_ATTRIBUTES
			article_meta.solution_articles.visible.each do |article|
	  		Resque.enqueue(Gamification::Quests::ProcessSolutionQuests, { :id => article.id, 
					:account_id => article.account_id })
			end
  	end
  end

  def process_topic_quests(topic)
  	changed_topic_attributes = topic.topic_changes.keys & TOPIC_UPDATE_ATTRIBUTES
  	if changed_topic_attributes.any? and !topic.user.customer?
  		Resque.enqueue(Gamification::Quests::ProcessTopicQuests, { :id => topic.id, 
						:account_id => topic.account_id })
  	end
  end

  def process_post_quests(post)
  	return if (post.user.customer? or post.user_id == post.topic.user_id)
			Resque.enqueue(Gamification::Quests::ProcessPostQuests, { :id => post.id, 
							:account_id => post.account_id }) 
  end

  def process_surveyresult_quests(sr)
  	queue_quest_calculation(sr.surveyable)
  end

  def queue_quest_calculation(scorable)
  	# Check if quest performance optimization is enabled for the account
  	if Account.current.launched?(:gamification_quest_perf)
  	  # Check cooldown for the user
  	  if !quest_cooldown?(scorable)
  	    # If no cooldown enqueue process and refresh cooldown
  	     Gamification::ProcessTicketQuests.perform_in(5.minute.from_now,
  	      { :user_id => scorable.responder.id, :account_id => scorable.account_id })
  	    set_quest_cooldown (scorable)
  	  end
  	else
  	  # If not enabled proceed as usual
  	  Resque.enqueue(Gamification::Quests::ProcessTicketQuests, {
  	    :id => scorable.id,:account_id => scorable.account_id })
  	end
  end

  private 

  def model_name(name)
    case name.class.name.to_sym
      when :"Helpdesk::Ticket"
         return "ticket"
      when :"CustomSurvey::SurveyResult"
          return "surveyresult"
      when :"Solution::Article"
          return "article"
      when :"Solution::ArticleMeta"
          return "article_meta"
      else
          return name.class.name.downcase
      end
  end

  def set_quest_cooldown (ticket)
    set_others_redis_key(redis_quest_key(ticket),true,5.minutes.to_i)
  end

  def quest_cooldown? (ticket)
    redis_key_exists?(redis_quest_key(ticket))
  end

  def redis_quest_key (ticket)
    GAMIFICATION_QUEST_COOLDOWN % { :account_id => ticket.account_id, :user_id => ticket.responder_id }
  end
end