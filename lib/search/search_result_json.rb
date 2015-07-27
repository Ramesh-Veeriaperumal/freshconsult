module Search::SearchResultJson

	include ApplicationHelper
	include ActionView::Helpers::DateHelper

	def helpdesk_ticket_json ticket
		return ticket_search_json(ticket) if @search_by_field
		return suggest_json(%{#{ticket.es_highlight('subject')} (##{ticket.display_id})},
				helpdesk_ticket_path(ticket), ticket) if @suggest
		to_ret = {
			:id => ticket.id,
			:result_type => 'helpdesk_ticket',
			:subject => ticket.es_highlight('subject'),
			:description => ticket.es_highlight('description'),
			:created_at => ticket.created_at
		}.merge!(ticket_fields_for_note(ticket))
	end

	def ticket_search_json(ticket)
		to_ret = {
			:id => ticket.id,
			:display_id => ticket.display_id,
			:subject => h(ticket.subject),
			:created_at => ticket.created_at,
			:created_at_int => ticket.created_at.to_i,
			:ticket_path => helpdesk_ticket_path(ticket),
			:searchKey => (params[:search_field] == "requester") ? "#{ticket.requester_name} #{ticket.from_email}" : ticket.send(params[:search_field]),
			:ticket_info => t("ticket.merge_ticket_list_status_created_at", 
							:username => "<span class='muted'>#{ticket.requester}</span>", 
							:time_ago => time_ago_in_words(ticket.created_at))
		}
	end

	def ticket_fields_for_note ticket
		{
			:ticket_priority => h(ticket.priority_name),
			:ticket_group => h(ticket.group_name),
			:ticket_display_id => h(ticket.display_id),
			:ticket_path => helpdesk_ticket_path(ticket),
			:avatar_url => user_avatar_url(ticket.requester),
			:ticket_info =>  t("ticket.ticket_list_status_" + ticket.ticket_states.current_state, 
							:username => requester(ticket),
							:time_ago => 
						time_ago_in_words(ticket.ticket_states.send(ticket.ticket_states.current_state))),
			:ticket_status => h(ticket.status_name),
			:responder_id => (ticket.responder.id unless ticket.responder.blank?),
			:responder_name => (ticket.responder.blank? ? '-' : ticket.responder.name)
		}
	end

	def helpdesk_note_json note
		ticket = note.notable
		return suggest_json(%{#{ticket.es_highlight('subject')} (##{ticket.display_id})},
					helpdesk_ticket_path(ticket), ticket) if @suggest
		to_ret = {
			:id => note.id,
			:result_type => 'helpdesk_note',
			:notable_id => note.notable_id,
			:notable_subject => h(note.notable.subject),
			:body => h(truncate(note.body, :length => 250))
		}.merge!(ticket_fields_for_note(note.notable))
	end

	def customer_json customer
		return suggest_json(%{#{customer.es_highlight('name')}},
				company_path(customer), customer) if @suggest
		to_ret = {
			:id => customer.id,
			:result_type => 'customer',
			:name => "#{customer.es_highlight('name')}",
			:path => company_path(customer),
			:domains => h(customer.domains)
		}
	end
	alias_method :company_json, :customer_json

	def user_json user
		return suggest_json(%{#{user.es_highlight('name')} - #{user.email}},
					user_path(user), user) if @suggest
		to_ret = {
			:id => user.id,
			:result_type => 'user',
			:path => user_path(user),
			:avatar_url => user_avatar_url(user),
			:name => "#{user.es_highlight('name')}",
			:email => (user.email unless user.email.blank?),
			:phone => (user.phone unless user.phone.blank?),
			:company_name => (h(user.company.name) unless user.company.blank?)
		}
	end

	def topic_json topic
		return suggest_json(%{#{topic.es_highlight('title')}},
				discussions_topic_path(topic), topic) if @suggest
		to_ret = {
			:id => topic.id,
			:result_type => 'topic',
			:title => topic.es_highlight('title'),
			:path => discussions_topic_path(topic),
			:forum_name => h(topic.forum.name),
			:forum_path => discussions_forum_path(topic.forum),
			:category_name => h(topic.forum.forum_category.name),
			:user_name => h(topic.user.name),
			:user_path => user_path(topic.user),
			:locked => topic.locked,
			:created_at => topic.created_at,
			:info => %{#{time_ago_in_words(topic.created_at)} #{t('search.ago')}},
			:description => truncate(topic.topic_desc, :length => 250),
			:searchKey => h(topic.title)
		}
	end

	def solution_article_json article
		return suggest_json(%{#{article.es_highlight('title').html_safe}},
							solution_article_path(article), article) if @suggest
		to_ret = {
			:id => article.id,
			:result_type => 'solution_article',
			:title => article.es_highlight('title').html_safe,
			:path => solution_article_path(article),
			:folder_name => h(article.folder.name),
			:folder_path => solution_category_folder_path(article.folder.category_id, article.folder),
			:description => article.es_highlight('desc_un_html'),
			:user_name => h(article.user.name),
			:user_path => user_path(article.user),
			:info => %{#{time_ago_in_words(article.created_at)} #{t('search.ago')}},
			:views => article.hits,
			:up_votes => article.thumbs_up,
			:down_votes =>article.thumbs_down
		}
	end

	def suggest_json content, path, result
		class_name = result.is_a?(Company) ? 'customer' : result.class.name.gsub('::', '_').downcase
		{
			:result_type => class_name,
			:content => content,
			:path => path
		}
	end
end