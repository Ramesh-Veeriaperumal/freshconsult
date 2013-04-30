module SupportHelper
	include Portal::PortalFilters
	include RedisKeys

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
					  # "Helvetica Neue" => "Helvetica+Neue:regular,italic,700,700italic" 
					}

    def time_ago date_time 
		%( <span class='timeago' data-timeago='#{date_time}' data-livestamp='#{date_time}'> 
			#{distance_of_time_in_words_to_now date_time} #{I18n.t('date.ago')} 
		   </span> )
	end

	def short_day_with_time date_time
		date_time.to_s(:short_day_with_time)
	end

	# Top page login, signup and user welcome information
	def welcome_navigation portal
		output = []
		
		# Showing welcome text before login link		
		output << %(<div class="welcome">#{ t('header.welcome') })

		# Showing logged in user name or displaying as Guest
		output << %(<b>#{ h((portal['user']).to_s) || t('header.guest') }</b> </div> )

		# Showing portal login link or signout link based on user logged in condition 
		if portal['user']
			# Showing profile settings path for loggedin user
			output << %(<b><a href="#{ portal['profile_url'] }">#{ t('header.edit_profile') }</a></b>)
			# Showing Signout path for loggedin user
			output << %(- <b><a href="#{ portal['logout_url'] }">#{ t('header.signout') }</a></b>)
		else
			# Showing login path for non-loggedin user
			output << %(<b><a href="#{ portal['login_url'] }">#{ t('header.login') }</a></b>)
			# Showing signup url based on customer portal settings feature
			output << %(&nbsp;<b><a href="#{ portal['signup_url'] }">#{ t('signup') }</a></b>) if portal['can_signup_feature']
		end

		output.join(" ")
	end

	# Helpcenter search, ticket creation buttons
	def helpcenter_navigation portal
		output = []
		output << %( <nav> )
		if portal['can_submit_ticket_without_login']
			output << %( <div>
							<a href="#{ portal['new_ticket_url'] }" class="mobile-icon-nav-newticket new-ticket ellipsis">
								<span> #{ I18n.t('header.new_support_ticket') } </span>
							</a>
						</div>) 
		else
			output << %(<div class="hide-in-mobile"><a href="#{portal['login_url']}">#{I18n.t('portal.login')}</a>)
			output << %( #{I18n.t('or')} <a href=\"#{portal['signup_url'] }\">
							#{I18n.t('portal.signup')}</a>) if portal['can_signup_feature']
			output << %( #{I18n.t('portal.to_submit_ticket')}</div> )
		end
		output << %(	<div>
							<a href="#{ portal['tickets_home_url'] }" class="mobile-icon-nav-status check-status ellipsis">
								<span>#{ I18n.t('header.check_ticket_status') }</span>
							</a>
						</div> )
		output << %( <div> <a href="#" class="mobile-icon-nav-contact contact-info ellipsis">
						<span>#{ portal['contact_info'] }</span>
					 </a> </div> ) if portal['contact_info']

		output << %(</nav>)
	end

	# User image page
	def profile_image user, more_classes = "", width = "50px", height = "50px" 
		output = []
		output << %( 	<div class="user-pic-thumb #{more_classes}">
							<img src="/images/fillers/profile_blank_thumb.gif" )
		output << %(			data-src="#{user['profile_url']}" rel="lazyloadimage" ) if user['profile_url']
		output << %(			width="#{width}" height="#{height}" />
						</div> )
		output.join("")
	end

	# No content information for forums
	def filler_for_forums portal		
		%( <div class='no-results'> #{I18n.t('portal.no_forums_info_1')} </div>
		   <div class='no-results'> #{ I18n.t('portal.no_forums_info_2', 
		   		:start_topic_link => link_to_start_topic(portal))} </div> )
	end

	def filler_for_solutions portal
		%( <div class="no-results">#{ I18n.t('portal.no_articles_info_1') }</div>
		   <div class="no-results">#{ I18n.t('portal.no_articles_info_2') }</div> )
	end

	def filler_for_folders folder
		%( <div class="no-results">#{ I18n.t('portal.folder.filler_text', :folder_name => h(folder['name'])) }</div> )
	end

	# Logo for the portal
	def logo portal
		_output = []
		_output << %(<a href='#{portal['linkback_url']}'>)
		# Showing the customer uploaded logo or default logo within an image tag
		_output << %(<img src='#{portal['logo_url']}' class='portal-logo' />)
		_output << %(</a>)
		_output.to_s
	end

	def portal_fav_ico
		fav_icon_content = MemcacheKeys.fetch(["v2","portal","fav_ico",current_portal]) do
			url = current_portal.fav_icon.nil? ? '/images/favicon.ico' : current_portal.fav_icon.content.url
			"<link rel='shortcut icon' href='#{url}' />"
		end
		fav_icon_content
	end

	# Default search filters for portal
	def default_filters search
		output = []
		output << %(<ul class="nav nav-pills nav-filter">)		
			search.filters.each do |f|
				output << %(<li class="#{search.current_filter == f[:name] ? "active" : ""}">)
				output << link_to(t("portal.search.filters.#{f[:name]}"), h(f[:url]))
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
	def follow_topic_button topic, follow_label = t('portal.topic.follow'), unfollow_label = t('portal.topic.following')
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

	def link_to_folder_with_count folder, *args
		label = " #{h(folder['name'])} <span class='item-count'>#{folder['articles_count']}</span>"
		content_tag :a, label, { :href => folder['url'], :title => h(folder['name']) }.merge(options)
	end

	def link_to_forum_with_count forum, *args
		label = " #{h(forum['name'])} <span class='item-count'>#{forum['topics_count']}</span>"
		content_tag :a, label, { :href => forum['url'], :title => h(forum['name']) }.merge(options)
	end

	def link_to_start_topic portal, *args
		options = link_args_to_options(args)
    	label = options.delete(:label) || I18n.t('portal.topic.start_new_topic')
    	content_tag :a, label, { :href => portal['new_topic_url'], :title => h(label) }.merge(options)
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
					<a href="#{article['url']}">#{h(article['title'])}</a>
				</div>
			</li>
HTML
		output.html_safe
	end

	def topic_list forum, limit = 5
		if(forum['topics_count'] > 0)
			topics = forum['topics']
			output = []
			output << %(<ul>#{ topics.take(limit).map { |t| topic_list_item t.to_liquid } })
			if topics.size > limit
				output << %(<a href="#{forum['url']}" class="see-more">) 
				output << %(#{ I18n.t('portal.topic.see_all_topics', :count => forum['topics_count']) })
				output << %(</a>) 
			end
			output << %(</ul>)
			output.join("")
		end
	end

	def topic_list_item topic
		output = <<HTML
			<li>
				<div class="ellipsis">
					<a href="#{topic['url']}">#{h(topic['title'])}</a>
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
		output << %(<div> #{last_post_brief(topic.to_liquid)} </div>) if topic.has_comments
		output.join(", ")
	end

	def topic_info_with_votes topic
		output = []
		output << topic_brief(topic)
		output << last_post_brief(topic.to_liquid) if topic.has_comments
		output << bold(topic_votes(topic)) if(topic.votes > 0)
		output.join(", ")
	end

	def last_post_brief topic, link_label = t('portal.topic.last_reply')
		if topic.last_post.present?
			post = topic.last_post.to_liquid
			%(<a href="#{topic.last_post_url}"> #{h(link_label)} </a> #{t('by')}
				#{h(post.user.name)} #{time_ago post.created_on})
		end
	end
		
	def topic_brief topic
		%(#{t('posted_by')} #{bold h(topic.user.name)}, #{time_ago topic.created_on})
	end

	def topic_votes topic
		pluralize topic.votes, "vote"
	end

	def topic_labels topic
		output = []
		output << %(<div class="topic-labels">)
		output << %(<span class="label label-sticky">
				#{t('topic.sticky')}</span>) if topic['sticky?']
		output << %(<span class="label label-answered">
				#{t('topic.answered')}</span>) if topic['answered?']
		output << %(<span class="label label-#{topic['stamp']}">
				#{t('topic.ideas_stamps.'+topic['stamp'])}</span>) if topic['stamp'].present?
		output << %(</div>)
		output.join('')
	end

	def post_topic_in_portal portal, post_topic = false
		output = []
		output << %(<section class="lead">)
		output << %(<a href="#{portal['login_url']}">#{I18n.t('portal.login')}</a>)
		output << I18n.t('portal.or_signup', :signup => 
				"<a href=\"#{portal['signup_url'] }\">#{I18n.t('portal.signup')}</a>") if 
					portal['can_signup_feature']
		if post_topic
			output << I18n.t("portal.to_post_topic")
		else
			output << I18n.t("portal.to_post_comment")
		end

		output << %(</section>)

		output.join('')
	end

	def link_to_topic_edit topic, label = I18n.t("topic.edit")
		if User.current == topic.user
			link_to label, topic['edit_url'], :title => label, :class => "btn btn-small"
		end
	end	

	def link_to_see_all_topics forum
		label = I18n.t('portal.topic.see_all_topics', :count => forum['topics_count'])
		link_to label, forum['url'], :title => label, :class => "see-more"
	end

	def link_to_see_all_articles folder
		label = I18n.t('portal.article.see_all_articles', :count => folder['articles_count'])
		link_to label, folder['url'], :title => label, :class => "see-more"
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

	def status_alert ticket
		_text = []
		_text << %( <b> #{ ticket['status'] } </b> )
		_text << I18n.t('since_last_time', :time_words => timediff_in_words(Time.now() - ticket['status_changed_on']))
		_text << %( <a href='#reply-to-ticket' data-proxy-for='#add-note-form' 
			data-show-dom='#reply-to-ticket'>#{ t('portal.tickets.reopen_reply') }</a> ) if ticket['closed?']
		content_tag :div, _text.join(" "), :class => "alert alert-ticket-status"
	end

	def ticket_field_container object_name, field, field_value = ""
		case field.dom_type
			when "checkbox" then
				%(  <div class="controls"> 
						<label class="checkbox">
							#{ ticket_form_element :helpdesk_ticket, field, field_value } #{ field[:label_in_portal] }
						</label>
					</div> )
			else
				%( #{ ticket_label object_name, field }
		   			<div class="controls"> 
		   				#{ ticket_form_element :helpdesk_ticket, field, field_value }
		   			</div> )
		end
	end

	def ticket_label object_name, field
		required = (field[:required_in_portal] && field[:editable_in_portal])
		element_class = " #{required ? 'required' : '' } control-label"
		label_tag "#{object_name}_#{field[:field_name]}", field[:label_in_portal], :class => element_class
	end

	def ticket_form_element object_name, field, field_value = ""
	    dom_type = (field.field_type == "nested_field") ? "nested_field" : field.dom_type	    
	    required = (field.required_in_portal && field.editable_in_portal)
	    element_class = " #{required ? 'required' : '' } #{ dom_type }"
	    field_name      = (field_name.blank?) ? field.field_name : field_name
	    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }"	    

	    case dom_type
	      when "requester" then
	      	render(:partial => "/support/shared/requester", :locals => { :object_name => object_name, :field => field })	      
	      when "text", "number" then
			text_field(object_name, field_name, :class => element_class + " span12", :value => field_value)
	      when "paragraph" then
			text_area(object_name, field_name, :class => element_class + " span12", :value => field_value, :rows => 6)
	      when "dropdown" then	        
          	select(object_name, field_name, 
          			field.field_type == "default_status" ? field.visible_status_choices : field.html_unescaped_choices, 
          			{:selected => field_value}, {:class => element_class})
	      when "dropdown_blank" then
	        select(object_name, field_name, field.html_unescaped_choices, 
	        		{ :include_blank => "...", :selected => field_value }, {:class => element_class})
	      when "nested_field" then
			nested_field_tag(object_name, field_name, field, 
	        	{:include_blank => "...", :selected => field_value}, 
	        	{:class => element_class}, field_value, true)
	      when "hidden" then
			hidden_field(object_name , field_name , :value => field_value)
	      when "checkbox" then
			check_box(object_name, field_name, :checked => field_value )
	      when "html_paragraph" then
	      	%( #{ text_area(object_name, field_name, :class => element_class, :value => field_value, :rows => 6) } 
	      	   #{ render(:partial=>"/support/shared/attachment_form") } )
	    end
	end

	# The field_value(init value) for the nested field should be in the the following format
	# { :category_val => "", :subcategory_val => "", :item_val => "" }
	def nested_field_tag(_name, _fieldname, _field, _opt = {}, _htmlopts = {}, _field_values = {}, in_portal = false)        
		_category = select(_name, _fieldname, _field.html_unescaped_choices, _opt, _htmlopts)
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
		font_url = args.uniq.map { |f| FONT_INCLUDES[f] }.reject{ |c| c.nil? }
		unless font_url.blank?
			"<link href='https://fonts.googleapis.com/css?family=#{font_url.join("|")}' rel='stylesheet' type='text/css'>"
		end
	end

	def portal_fonts
		include_google_font portal_preferences.fetch(:baseFont, ""), 
			portal_preferences.fetch(:headingsFont, "")
	end

	def ticket_field_display_value(field, ticket)
		_field_type = field.field_type
		_field_value = (field.is_default_field?) ? ticket.send(field.field_name) : ticket.get_ff_value(field.name)
		_dom_type = (_field_type == "default_source") ? "dropdown" : field.dom_type

		case _dom_type
			when "dropdown", "dropdown_blank"
			    if(_field_type == "default_agent")
					ticket.responder.name if ticket.responder
			    elsif(_field_type == "nested_field" || _field_type == "nested_child")
					ticket.get_ff_value(field.name)
			    else
					field.dropdown_selected(((_field_type == "default_status") ? 
						field.all_status_choices : field.html_unescaped_choices), _field_value)
			    end
			when "checkbox"
				_field_value ? I18n.t('plain_yes') : I18n.t('plain_no')
			else
			  	_field_value
		end
	end

	def ticket_field_form_value(field, ticket)
		form_value = (field.is_default_field?) ? 
		              ticket.send(field.field_name) : ticket.get_ff_value(field.name)

		if(field.field_type == "nested_field")
			form_value = {}
			field.nested_levels.each do |ff|
			form_value[(ff[:level] == 2) ? :subcategory_val : :item_val] = ticket.get_ff_value(ff[:name])
			end
			form_value.merge!({:category_val => ticket.get_ff_value(field.name)})
		end

		return form_value
	end

	# Portal placeholders to access dynamic data inside javascripts
	def portal_access_varibles
		output = []
		output << %( <script type="text/javascript"> )
		output << %(  	var portal = #{portal_javascript_object}; )
		output << %( </script> )
		output.join("")
	end

	def portal_javascript_object
		{ :language => @portal['language'],
		  :name => @portal['name'],
		  :contact_info => @portal['contact_info'],
		  :current_page => @portal['page'],
		  :current_tab => @portal['current_tab'] }.to_json
	end

	def theme_url
		preview? ? "/theme/#{current_portal.template.id}-#{current_user.id}-preview.css?v=#{Time.now.to_i}" : 
			"/theme/#{current_portal.template.id}.css?v=#{current_portal.template.updated_at.to_i}"
	end

	def portal_copyright portal
		%( 	<div class="copyright">
				<a href="http://www.freshdesk.com" target="_blank"> #{ I18n.t('footer.helpdesk_software') } </a>
				#{ I18n.t('footer.by_freshdesk') }
			</div> ) unless portal.paid_account
	end

	def link_to_cookie_law portal
		%(	<a href="#portal-cookie-info" rel="freshdialog" class="cookie-link" 
				data-width="450px" title="#{ I18n.t('portal.cookie.why_we_love_cookies') }" data-template-footer="">
				#{ I18n.t('portal.cookie.cookie_policy') }
			</a>)
	end

	def cookie_law
		privacy_link = %(<a href="http://freshdesk.com/privacy/" target="_blank">#{ I18n.t('portal.cookie.privacy_policy') }</a>)
		%(  <div id="portal-cookie-info" class="hide">
				<p>#{ I18n.t('portal.cookie.cookie_dialog_info1') }</p>
				<p>#{ I18n.t('portal.cookie.cookie_dialog_info2', :privacy_link => privacy_link) }</p>
				<p>#{ I18n.t('portal.cookie.cookie_dialog_info3', :privacy_link => privacy_link) }</p>
			</div>)
	end

	private

		def portal_preferences
			preferences = current_portal.template.preferences
		    preferences = current_portal.template.get_draft.preferences if preview? && current_portal.template.get_draft
		    preferences || []
		end

		def preview?
			if User.current
		        is_preview = IS_PREVIEW % { :account_id => current_account.id, 
		        :user_id => User.current.id, :portal_id => @portal.id}
		        !get_key(is_preview).blank? && !current_user.blank? && current_user.agent?
		    end
	    end

		def link_args_to_options(args)
	      options = {}
	      [:label, :title, :id, :class, :rel].zip(args) {|key, value| options[key] = h(value) unless value.blank?}
	      options
	    end
end

