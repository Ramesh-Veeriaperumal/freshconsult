module SupportHelper
	include ActionView::Helpers::TagHelper
	include Portal::PortalFilters

	FONT_INCLUDES = { "Source Sans Pro" => "Source+Sans+Pro:regular,italic,700,700italic",
					  "Droid Sans" => "Droid+Sans:regular,700",
					  "Lato" => "Lato:regular,italic,900,900italic",
					  "Arvo" => "Arvo:regular,italic,700,700italic",
					  "Droid Serif" => "Droid+Serif:regular,italic,700,700italic",
					  "Oswald" => "Oswald:regular,700",
					  "Open Sans Condensed" => "Open+Sans+Condensed:300,300italic,700",
					  "Open Sans" => "Open+Sans:regular,italic,700,700italic",
					  "Merriweather" => "Merriweather:regular,700",
					  "Roboto Condensed" => "Roboto+Condensed:regular,italic,700,700italic",
					  "Roboto" => "Roboto:regular,italic,700,700italic",
					  "Varela Round" => "Varela+Round:regular",
					  "Vast Shadow" => "Vast+Shadow:regular",
					  "Helvetica Neue" => "Helvetica+Neue:regular,italic,700,700italic" }

	# Top page login, signup and user welcome information
	def welcome_navigation portal
		output = []
		
		# Showing welcome text before login link		
		output << %(<div class="welcome">#{ t('header.welcome') })

		# Showing logged in user name or displaying as Guest
		output << %(<b>#{ portal['current_user'] || t('header.guest') }</b> </div> )

		# Showing portal login link or signout link based on user logged in condition 
		if portal['current_user']
			# Showing profile settings path for loggedin user
			output << %(<b><a href="#{ portal['profile_path'] }">#{ t('header.edit_profile') }</a></b>)
			# Showing Signout path for loggedin user
			output << %(- <b><a href="#{ portal['logout_path'] }">#{ t('header.signout') }</a></b>)
		else
			# Showing login path for non-loggedin user
			output << %(<b><a href="#{ portal['login_path'] }">#{ t('header.login') }</a></b>)
			# Showing signup url based on customer portal settings feature
			output << %(or <b><a href="#{ portal['signup_path'] }">#{ t('signup') }</a></b>) if portal['can_signup_feature?']
		end

		output.join(" ")
	end

	# Helpcenter search, ticket creation buttons
	def help_center portal
		
	end

	# No content information for forums
	def filler_for_forums portal		
		%( <div class='lead'> #{I18n.t('portal.no_forums_info_1')} </div>
		   <div class='lead-small'> #{ I18n.t('portal.no_forums_info_2', :start_topic_link => link_to_start_topic(portal))} </div> )
	end

	# Logo for the portal
	def logo portal
		_output = []
		_output << %(<a href='#{portal['linkback_url']}'>)
		# Showing the customer uploaded logo or default logo within an image tag
		_output << %(<img src='#{portal['logo_url']}' class='portal-logo' />)
		_output << %(</a>)
		_output.join(" ")
	end

	# Default search filters for portal
	def default_filters search
		output = []
		output << %(<ul class="nav nav-pills nav-filter">)		
			search.filters.each do |f|
				output << %(<li class="#{search.current_filter == f[:name] ? "active" : ""}">)
				output << link_to(t("portal.search.filters.#{f[:name]}"), f[:url])
				output << %(</li>)
			end
		output << %(</ul>)
	end

	# Default topic filter that shows up in the topic list
	def default_topic_filters forum
		output = []
		output << %(<ul class="nav nav-pills nav-filter">)		
			forum.allowed_filters.each do |f|
				output << %(<li class="#{forum.current_topic_filter == f[:name] ? "active" : ""}">)
				output << link_to(t("forums_order.#{f[:name]}"), f[:url])
				output << %(</li>)
			end
		output << %(</ul>)
	end

	# Follow/unfollow button 
	# To modify label the liquid can be modified as so
	# {{ topic | follow_topic_button : "Click to follow", "Click to unfollow" }}
	def follow_topic_button topic, follow_label = "Follow", unfollow_label = "Following"
		if User.current
			_monitoring = !Monitorship.count(:id, 
							:conditions => ['user_id = ? and topic_id = ? and active = ?', 
							User.current.id, topic['id'], true]).zero?

			link_to _monitoring ? unfollow_label : follow_label, topic['toggle_follow_url'], 
				"data-remote" => true, "data-method" => :put, 
				:id => "topic-monitor-button",
				:class => "btn btn-small #{_monitoring ? 'active' : ''}",
				"data-toggle" => "button",
				"data-button-active-label" => unfollow_label, 
				"data-button-inactive-label" => follow_label
		end
	end

	def link_to_start_topic portal, *args
		options = link_args_to_options(args)
    	label = options.delete(:label) || I18n.t('portal.topic.start_new_topic')
    	content_tag :a, label, { :href => portal['new_topic_path'], :title => label }.merge(options)
	end

	def article_list folder, limit = 5, reject_article = nil
		if(folder.present? && folder['articles_count'] > 0)
			articles = folder['articles']
			articles.reject!{|a| a['id'] == reject_article['id']} if(reject_article != nil)
 			output = []
			output << %(<ul>#{ articles.take(limit).map { |a| article_list_item a.to_liquid } }</ul>)
			if articles.size > limit
				output << %(<a href="#{folder['url']}" class="see-more">) 
				output << %(#{ I18n.t('portal.article.see_all_articles', :count => folder['articles_count']) })
				output << %(</a>) 
			end
			output.join("")
		end
	end	

	def article_list_item article
		output = <<HTML
			<li>
				<div class="ellipsis">
					<a href="#{article['url']}">#{article['title']}</a>
				</div>
			</li>
HTML
		output.html_safe
	end

	def topic_list forum, limit = 5
		if(forum['topics_count'] > 0)
			topics = forum['topics']
			output = []
			output << %(<ul>#{ topics.take(limit).map { |t| topic_list_item t.to_liquid } }</ul>)
			if topics.size > limit
				output << %(<a href="#{forum['url']}" class="see-more">) 
				output << %(#{ I18n.t('portal.topic.see_all_topics', :count => forum['topics_count']) })
				output << %(</a>) 
			end
			output.join("")
		end
	end

	def topic_list_item topic
		output = <<HTML
			<li>
				<div class="ellipsis">
					<a href="#{topic['url']}">#{topic['title']}</a>
				</div>
				<div class="help-text">
					#{ topic_info topic }
				</div>
			</li>
HTML
		output.html_safe
	end

	def topic_info topic
		output = []
		output << topic_brief(topic)
		output << %(<div> #{post_brief(topic.last_post.to_liquid)} </div>) if topic.has_comments
		output.join(", ")
	end

	def topic_info_with_votes topic
		output = []
		output << topic_brief(topic)
		output << post_brief(topic.last_post.to_liquid) if topic.has_comments
		output << bold(topic_votes(topic)) if(topic.votes > 0)
		output.join(", ")
	end
		
	def topic_brief topic
		%(Posted by #{bold topic.user.name}, #{time_ago topic.created_on})
	end

	def topic_votes topic
		pluralize topic.votes, "vote"
	end

	def link_to_topic_edit topic, label = I18n.t("topic.edit")
		if User.current == topic.user
			link_to label, topic['edit_url'], :title => label, :class => "btn btn-small"
		end
	end

	def post_brief post, link_label = "Last reply"
		if post.present?
			%(<a href="#{post.url}"> #{link_label} </a> by #{post.user.name} #{time_ago post.created_on})
		end
	end

	def post_actions post
		if User.current == post.user
			output = <<HTML
				<span class="dropdown pull-right">
					<ul class="dropdown-menu" role="menu" aria-labelledby="dropdownMenu">
						<li>
						<a href="#{ post["edit_url"] }" data-remote data-type="GET" data-loadonce
								 	data-update="#post-#{post["id"]}-edit" data-show-dom="#post-#{post["id"]}-edit"
								    data-hide-dom="#post-#{post["id"]}-description">
									#{t("edit")}
						</a>
						</li>
						<li>
				     		<a href="#{ post["delete_url"] }" data-method="delete"
				     			data-confirm="This post will be delete permanently. Are you sure?">
				     			#{t("delete")}
				     		</a>
			     		</li>
			     	</ul>
				    <a href="#" class="dropdown-toggle btn btn-icon post-actions" data-toggle="dropdown">
						<i class="icon-cog-drop-dark"></i>
					</a>
				</span>
HTML
			output.html_safe
		end
	end

	# Ticket specific helpers
	def survey_text survey_result
		if survey_result != 0
			Account.current.survey.title(survey_result)
		end
	end

	# Construct ticket form UI
	def construct_ticket_element(object_name, field, field_label, dom_type, required, field_value = "", field_name = "", in_portal = false , is_edit = false)
	    dom_type = (field.field_type == "nested_field") ? "nested_field" : dom_type
	    element_class   = " #{ (required) ? 'required' : '' } #{ dom_type }"
	    field_name      = (field_name.blank?) ? field.field_name : field_name
	    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }"
	    label = label_tag object_name+"_"+field.field_name, field_label, :class => ((dom_type != "checkbox") ? ("#{required ? 'required': ""} control-label") : "")
	    case dom_type
	      when "requester" then
	      	element = render(:partial => "/support/shared/requester", 
	      		:locals => { :label => label, :object_name => object_name, :field => field })
	      when "email" then
	        element = label + content_tag(:div, text_field(object_name, field_name, :class => element_class, :value => field_value), :class => "controls")
	        element = add_cc_field_tag element ,field if (field.portal_cc_field? && !is_edit && controller_name.singularize != "feedback_widget") #dirty fix
	        element += add_name_field unless is_edit
	      when "text", "number" then
	        element = label + content_tag(:div, text_field(object_name, field_name, :class => element_class + " span12", :value => field_value), :class => "controls")
	      when "paragraph" then
	        element = label + content_tag(:div, text_area(object_name, field_name, :class => element_class + " span12", :value => field_value, :rows => 6), :class => "controls")
	      when "dropdown" then	        
          	element = label + content_tag(:div, 
          		select(object_name, field_name, field.field_type == "default_status" ? field.visible_status_choices : field.choices, 
          			{:selected => field_value}, {:class => element_class}), :class => "controls")
	      when "dropdown_blank" then
	        element = label + content_tag(:div, 
	        	select(object_name, field_name, field.choices, { :include_blank => "...", :selected => field_value }, {:class => element_class}), :class => "controls")
	      when "nested_field" then
	        element = label + content_tag(:div, nested_field_tag(object_name, field_name, field, {:include_blank => "...", :selected => field_value}, {:class => element_class}, field_value, in_portal), :class => "controls")
	      when "hidden" then
	        element = hidden_field(object_name , field_name , :value => field_value)
	      when "checkbox" then
	        element = content_tag(:div, check_box(object_name, field_name, :class => element_class, :checked => field_value ) + label, :class => "controls")
	      when "html_paragraph" then
	      	_output = []
	      	_output << %( #{ text_area(object_name, field_name, :class => element_class, :value => field_value, :rows => 6) } )
	      	_output << %( #{ render(:partial=>"/support/shared/attachment_form") } )
	        element = label + content_tag(:div, _output.join(" "), :class => "controls")
	    end
	    content_tag :div, element, :class => dom_type+" control-group"
	 end

	def add_cc_field_tag element , field    
		if current_user && current_user.agent? 
		  element  = element + content_tag(:div, render(:partial => "/shared/cc_email_all.html")) 
		elsif current_user && current_user.customer? && field.all_cc_in_portal?
		  element  = element + content_tag(:div, render(:partial => "/shared/cc_email_all.html"))
		else
		   element  = element + content_tag(:div, render(:partial => "/shared/cc_email.html")) if (current_user && field.company_cc_in_portal? && current_user.customer) 
		end
		return element
	end

	def add_requester_field
		content_tag(:div, render(:partial => "/shared/add_requester")) if (current_user && current_user.can_view_all_tickets?)
	end

	def add_name_field
		content_tag(:li, content_tag(:div, render(:partial => "/shared/name_field")),
			:id => "name_field", :class => "hide") unless current_user
	end

	# The field_value(init value) for the nested field should be in the the following format
	# { :category_val => "", :subcategory_val => "", :item_val => "" }
	def nested_field_tag(_name, _fieldname, _field, _opt = {}, _htmlopts = {}, _field_values = {}, in_portal = false)        
		_category = select(_name, _fieldname, _field.choices, _opt, _htmlopts)
		_javascript_opts = {
		  :data_tree => _field.nested_choices,
		  :initValues => _field_values,
		  :disable_children => false
		}.merge!(_opt)

		_field.nested_levels.each do |l|       
		  _javascript_opts[(l[:level] == 2) ? :subcategory_id : :item_id] = (_name +"_"+ l[:name]).gsub('[','_').gsub(']','')
		  _category += content_tag :div, content_tag(:label, l[(!in_portal)? :label : :label_in_portal]) + select(_name, l[:name], [], _opt, _htmlopts), :class => "level_#{l[:level]}"
		end

		_category + javascript_tag("jQuery(document).ready(function(){jQuery('##{(_name +"_"+ _fieldname).gsub('[','_').gsub(']','')}').nested_select_tag(#{_javascript_opts.to_json});})")
	end

	# NON-FILTER HELPERS

	# Options list for forums in new and edit topics page
	def forum_options
		_forum_options = []
		current_portal.forum_categories.each do |c| 
			_forums = c.forums.visible(current_user).reject(&:announcement?).map{ |f| [f.name, f.id] }
			_forum_options << [ c.name, _forums ] if _forums.present?
		end
		_forum_options
	end

	# Search url for different tabs
	def tab_based_search_url
		case @current_tab
			when 'tickets'
				tickets_support_search_path
			when 'solutions'
				solutions_support_search_path
			when 'forums'
				topics_support_search_path
			else
				support_search_path
		end
	end

	# Including google font for portal
	def include_google_font *args
		font_url = args.map { |f| FONT_INCLUDES[f] }
		unless font_url.blank?
			"<link href='http://fonts.googleapis.com/css?family=#{font_url.join("|")}' rel='stylesheet' type='text/css'>"
		end
	end

	def portal_fonts
		include_google_font portal_preferences.fetch(:baseFont, ""), 
			portal_preferences.fetch(:headingsFont, ""), "Helvetica Neue"
	end

	private

		def portal_preferences
			preferences = current_portal.template.preferences
		    preferences = current_portal.template.get_draft.preferences if preview? && current_portal.template.get_draft
		    preferences || []
		end

		def preview?
	      !session[:preview_button].blank? && !current_user.blank? && current_user.agent?
	    end

		def link_args_to_options(args)
	      options = {}
	      [:label, :title, :id, :class, :rel].zip(args) {|key, value| options[key] = h(value) unless value.blank?}
	      options
	    end
end

