module Search::SearchResultJson

	include ApplicationHelper
	include ActionView::Helpers::DateHelper
	include HumanizeHelper
	include Solution::PathHelper

	def helpdesk_ticket_json ticket
		return ticket_search_json(ticket) if @search_by_field || @recent_trackers
		return suggest_json(%{#{ticket.es_highlight('subject')} (##{ticket.display_id})},
				helpdesk_ticket_path(ticket), ticket) if @suggest
		to_ret = {
			:id => ticket.id,
			:result_type => 'helpdesk_ticket',
			:subject => ticket.es_highlight('subject'),
			:description => ticket.es_highlight('description'),
			:created_at => ticket.created_at,
			:archive => false
		}.merge!(ticket_fields_for_note(ticket))
	end

	def ticket_search_json(ticket)
		to_ret = {
			:id => ticket.id,
			:display_id => ticket.display_id,
			:requester_id => ticket.requester_id,
			:subject => h(ticket.subject),
			:created_at => ticket.created_at,
			:created_at_int => ticket.created_at.to_i,
			:ticket_path => helpdesk_ticket_path(ticket),
			:ticket_status => h(ticket.status_name),
			:ticket_info => t("ticket.merge_ticket_list_status_created_at", 
							:username => "<span class='muted'>#{ticket.requester}</span>", 
							:time_ago => time_ago_in_words(ticket.created_at))
		}
		to_ret.merge!({ 
			:searchKey => (params[:search_field] == "requester") ? "#{ticket.requester_name} #{ticket.from_email}" : ticket.safe_send(params[:search_field]) 
		}) if params[:search_field].present?
		to_ret
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
						time_ago_in_words(ticket.ticket_states.safe_send(ticket.ticket_states.current_state))),
			:ticket_status => h(ticket.status_name),
			:ticket_status_id => ticket.status,
			:responder_id => (ticket.responder.id unless ticket.responder.blank?),
			:responder_name => (ticket.responder.blank? ? '-' : ticket.responder.name)
		}
	end

	# *********Archive Ticket Methods starts here**********
	def helpdesk_archive_ticket_json ticket
		return archive_ticket_search_json(ticket) if @search_by_field
		return suggest_json(%{#{ticket.es_highlight('subject')} (##{ticket.display_id})},
				helpdesk_archive_ticket_path(ticket.display_id), ticket) if @suggest
		to_ret = {
			:id => ticket.id,
			:result_type => 'helpdesk_ticket',
			:subject => ticket.es_highlight('subject'),
			:description => ticket.es_highlight('description'),
			:created_at => ticket.created_at,
			:archive => true
		}.merge!(archive_ticket_fields_for_note(ticket))
	end

	def archive_ticket_search_json(ticket)
		to_ret = {
			:id => ticket.id,
			:display_id => ticket.display_id,
			:subject => h(ticket.subject),
			:created_at => ticket.created_at,
			:created_at_int => ticket.created_at.to_i,
			:ticket_path => helpdesk_archive_ticket_path(ticket.display_id),
			:searchKey => (params[:search_field] == "requester") ? "#{ticket.requester_name} #{ticket.from_email}" : ticket.safe_send(params[:search_field]),
			:ticket_info => t("ticket.merge_ticket_list_status_created_at", 
							:username => "<span class='muted'>#{ticket.requester}</span>", 
							:time_ago => time_ago_in_words(ticket.created_at))
		}
	end

	def archive_ticket_fields_for_note ticket
		{
			:ticket_priority => h(ticket.priority_name),
			:ticket_group => h(ticket.group_name),
			:ticket_display_id => h(ticket.display_id),
			:ticket_path => helpdesk_archive_ticket_path(ticket.display_id),
			:avatar_url => user_avatar_url(ticket.requester),
			:ticket_info =>  t("ticket.ticket_list_status_" + ticket.ticket_states.current_state, 
							:username => requester(ticket),
							:time_ago => 
						time_ago_in_words(ticket.ticket_states.safe_send(ticket.ticket_states.current_state))),
			:ticket_status => h(ticket.status_name),
			:ticket_status_id => ticket.status,
			:responder_id => (ticket.responder.id unless ticket.responder.blank?),
			:responder_name => (ticket.responder.blank? ? '-' : ticket.responder.name)
		}
	end

	def helpdesk_archive_note_json note
		ticket = note.archive_ticket
		return suggest_json(%{#{ticket.es_highlight('subject')} (##{ticket.display_id})},
					helpdesk_archive_ticket_path(ticket.display_id), ticket) if @suggest
		to_ret = {
			:id => note.id,
			:result_type => 'helpdesk_note',
			:notable_id => note.archive_ticket_id,
			:notable_subject => h(note.archive_ticket.subject),
			:body => h(truncate(note.body, :length => 250))
		}.merge!(archive_ticket_fields_for_note(note.archive_ticket))
	end


	# *********Archive Ticket Methods ends here**********
	
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
		author = article.modified_by ? article.recent_author : article.user
		to_ret = {
			:id => article.id,
			:result_type => 'solution_article',
			:title => article.es_highlight('title').html_safe,
			:path => multilingual_article_path(article),
			:folder_name => h((article.solution_folder_meta.safe_send("#{article.language.to_key}_folder") || article.solution_folder_meta.primary_folder).name),
			:folder_path => solution_folder_path(article.solution_folder_meta),
			:description => article.es_highlight('desc_un_html'),
			:user_name => h(author.name),
			:user_path => user_path(author),
			:info => %{#{time_ago_in_words(article.modified_at || article.created_at)} #{t('search.ago')}},
			:views => humanize_stats(article.hits),
			:up_votes => humanize_stats(article.thumbs_up),
			:down_votes => humanize_stats(article.thumbs_down)
		}
	end

	def suggest_json content, path, result
		if Account.current.features_included?(:archive_tickets) && result.class.name == "Helpdesk::ArchiveTicket" 
		  class_name = "helpdesk_ticket"
		else
          class_name = result.is_a?(Company) ? 'customer' : result.class.name.gsub('::', '_').downcase
		end
		{
			:result_type => class_name,
			:content => content,
			:path => path,
			:id => result.id || 0
		}
	end
end
