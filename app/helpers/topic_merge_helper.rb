module TopicMergeHelper

	def display_template(topic, tag=nil)
		output = []
		output << "<div data-id='#{topic.id}' class='merge-topic' data-created='#{topic.created_at.to_i}'>"
		output << title_link(topic)
		output << hidden_field_tag(tag, topic.to_param) if tag
		output << '<div class="info-data"><span class="merge-topic-info">'
		output << t("discussions.topic_merge.merge_topic_list_status_created_at", 
									:username => "<span class='muted requester_name'>#{h(topic.user.name)}</span>",
									:forum => topic.forum.name,
									:time_ago => time_ago_in_words(topic.created_at))
		output << '</span></div></div>'
		output.join("").html_safe
	end

	def title_link(topic)
		link_to( topic.title, discussions_topic_path(topic), :title => topic.title, :class =>"item_info", :target=>"_blank" )
	end

end