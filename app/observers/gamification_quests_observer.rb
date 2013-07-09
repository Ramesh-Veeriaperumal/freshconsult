class GamificationQuestsObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket, Solution::Article, Topic, Post, SurveyResult

	include Gamification::GamificationUtil

	SOLUTION_UPDATE_ATTRIBUTES = ["folder_id", "status", "thumbs_up"]
	TOPIC_UPDATE_ATTRIBUTES = ["forum_id", "user_votes"]

	def after_commit_on_create(model)
		return unless gamification_feature?(model.account)
		process_quests(model)
	end

	def after_commit_on_update(model)
		return unless (!([:Post,:SurveyResult].include? model.class.name.to_sym) and gamification_feature?(model.account))
		process_quests(model)
	end

	private

	def process_quests(model)
		model_name = (:"Helpdesk::Ticket".eql? model.class.name.to_sym)  ? "ticket" : (
			(:"Solution::Article".eql? model.class.name.to_sym)  ? "article" : model.class.name.downcase)
		send("process_#{model_name}_quests", model)
		rollback_achieved_quests(model) if :"Helpdesk::Ticket".eql? model.class.name.to_sym
		
	end

	def process_ticket_quests(ticket)
  	if ticket.responder and ticket.resolved_now?
  		Resque.enqueue(Gamification::Quests::ProcessTicketQuests, { :id => ticket.id, 
  							:account_id => ticket.account_id })
  	end
  end

  def rollback_achieved_quests(ticket)
  	if ticket.responder and ticket.reopened_now?
  		Resque.enqueue(Gamification::Quests::ProcessTicketQuests, { :id => ticket.id, 
  							:account_id => ticket.account_id, :rollback => true,
  							:resolved_time_was => ticket.ticket_states.resolved_time_was })
  	end
  end

  def process_article_quests(article)
  	changed_article_attributes = article.article_changes.keys & SOLUTION_UPDATE_ATTRIBUTES
  	if changed_article_attributes.any? and article.published?
  		Resque.enqueue(Gamification::Quests::ProcessSolutionQuests, { :id => article.id, 
				:account_id => article.account_id })
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
    Resque.enqueue(Gamification::Quests::ProcessTicketQuests, { :id => sr.surveyable_id, 
                :account_id => sr.account_id })
  end

end