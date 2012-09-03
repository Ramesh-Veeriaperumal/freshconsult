module ProcessQuests

	def scoper()
    	Account.current.quests
  	end

  	def solutions_scoper()
  		Account.current.solution_articles
  	end

  	def posts_scoper()
  		Account.current.posts
  	end
  	
  	def tickets_scoper()
  		Account.current.tickets
  	end

  	def process_tickets_quest(ticket)
  		unless ticket.active?
	  		ticket.status
				puts "testing----------------------->>>>>>  12121"
				ticket_quests = scoper.ticket_quests
				ticket_quests.each do |f|
					quest_value = f.quest_data[0][:value].to_i 
					award_point = f.award_data[0][:point]
					award_badge = f.award_data[0][:badge]
					tickets_count = tickets_scoper.assigned_to(ticket.responder).count()
					if quest_value == tickets_count
						SupportScore.add_ticket_score(ticket, award_point, award_badge)
					end
				end
		end
	end

  def process_forums_quest(post)
  	if post.user.agent?
			forums_quests = scoper.forum_quests
			forums_quests.each do |f|
				quest_value = f.quest_data[0][:value].to_i 
				award_point = f.award_data[0][:point]
				award_badge = f.award_data[0][:badge]
				posts_count = posts_scoper.user(post.user.id).count()
				if quest_value == posts_count
					SupportScore.add_score(post, award_point, award_badge)
				end
			end
		end
	end

	def process_solutions_quest(article)
		unless !article.user.agent? 
			solutions_quests = scoper.solution_quests
			solutions_quests.each do |s|
				quest_value = s.quest_data[0][:value].to_i 
				article_count = solutions_scoper.visible.user(article.user.id).count()
				award_point = s.award_data[0][:point]
				award_badge = s.award_data[0][:badge]
				if quest_value == article_count
					SupportScore.add_score(article, award_point, award_badge)
				end
			end
		end
	end
end