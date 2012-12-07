module SupportHelper
	include ActionView::Helpers::TagHelper
	include ActionView::Helpers::DateHelper
	include ActionView::Helpers::UrlHelper
	
	# ActionView::Base.default_form_builder = FormBuilders::RedactorBuilder
	
	# Forum based helpers 
	# Have to move these into their respective pages
	def bold content
		content_tag :strong, content
	end

	def day_and_time date_time
		date_time.to_s :long_day_with_time
	end

	def time_ago date_time 
		"#{distance_of_time_in_words_to_now date_time} ago"
	end

	# rendering partial if its corresponding db_file is not available
	def portal_render local_file, db_file = ""
		# render_to_string :partial => local_file, :locals => { :dynamic_template => db_file }
	end

	# Top page login, signup and user welcome information
	def welcome_navigation portal
		output = []
		
		# Showing welcome text before login link		
		output << %(<div class="welcome"> #{ t('header.welcome') })

		# Showing logged in user name or displaying as Guest
		output << %(<b>#{ portal['user'] || t('header.guest') }</b> </div> )

		# Showing portal login link or signout link based on user logged in condition 
		if portal['user']			
			output << %(<b><a href="#{ portal['logout_path'] }">#{ t('header.signout') }</a></b>)
		else
			output << %(<b><a href="#{ portal['login_path'] }">#{ t('header.login') }</a></b>)
			# Showing signup url based on customer portal settings feature
			output << %(or <b><a href="#{ portal['signup_path'] }">#{ t('signup') }</a></b>) if portal['can_signup_feature?']
		end

		output.join(" ")
	end


	# Ticket info for list view
	def default_info(ticket)
		output = []
		unless ticket.requester.nil? or User.current.eql?(ticket.requester)
			output << %(#{I18n.t('ticket.portal_created_on', { :username => h(ticket.requester.name), :date => ticket.created_on })})
		else
			output << %(#{I18n.t('ticket.portal_created_on_same_user', { :date => ticket.created_on })})
		end

		output << %(#{I18n.t('ticket.assigned_agent')}: <span class='emphasize'> #{ticket.agent.name}</span>) unless ticket.agent.blank?
		
		output.join(" ")
	end

	# Pageination filter for generating the pagination links
	def default_pagination(paginate, previous_label = "&laquo; #{I18n.t('previous')}", next_label = "#{I18n.t('next')} &raquo;")
	    html = []
	    if paginate['parts'].size > 0
		    html << %(<div class="pagination"><ul>)
		    if paginate['previous']
		    	html << %(<li class="prev">#{link_to(previous_label, paginate['previous']['url'])}</li>)
		    else
		    	html << %(<li class="prev disabled"><a>#{previous_label}</a></li>)
		    end

		    for part in paginate['parts']
		      if part['is_link']
		        html << %(<li>#{link_to(part['title'], part['url'])}</li>)        
		      elsif part['title'].to_i == paginate['current_page'].to_i
		        html << %(<li class="disabled gap"><a>#{part['title']}</a></li>)        
		      else
		        html << %(<li class="active"><a>#{part['title']}</a></li>)
		      end	      
		    end

		    if paginate['next']
		    	html << %(<li class="next">#{link_to(next_label, paginate['next']['url'])}</li>)
		    else
		    	html << %(<li class="next disabled"><a>#{next_label}</a></li>)
		   	end

		    html << %(</ul></div>)
		end		
	    html.join(' ')
	    # windowed_links
	end

	def windowed_links
      prev = nil

      visible_page_numbers(0, 100).inject [] do |links, n|
        # detect gaps:
        links << %(<a>&hellip;</a>) if prev and n > prev + 1
        links << %(<a>#{n}</a>)
        prev = n
        links
      end
    end

	def visible_page_numbers current_page, total_pages
	    inner_window, outer_window = 4, 1
	    window_from = current_page - inner_window
	    window_to = current_page + inner_window
	    
	    # adjust lower or upper limit if other is out of bounds
	    if window_to > total_pages
	      window_from -= window_to - total_pages
	      window_to = total_pages
	    end
	    if window_from < 1
	      window_to += 1 - window_from
	      window_from = 1
	      window_to = total_pages if window_to > total_pages
	    end
	    
	    visible   = (1..total_pages).to_a
	    left_gap  = (2 + outer_window)...window_from
	    right_gap = (window_to + 1)...(total_pages - outer_window)
	    visible  -= left_gap.to_a  if left_gap.last - left_gap.first > 1
	    visible  -= right_gap.to_a if right_gap.last - right_gap.first > 1

	    visible    
	  end

	# Applicaiton link helpers
	# !PORTALCSS move this area INTO link_helpers later
	def login_via_google label
		link_to(label, "/auth/open_id?openid_url=https://www.google.com/accounts/o8/id", :class => "btn btn-google") if Account.current.features? :google_signin
	end
	
	def login_via_twitter label
		link_to(label, "/auth/twitter", :class => "btn btn-twitter") if Account.current.features? :twitter_signin
	end

	def login_via_facebook label
		link_to(label, "/sso/facebook", :class => "btn btn-facebook") if Account.current.features? :facebook_signin
	end
	
	# Topic specific filters

	# Follow/unfollow button 
	# To modify label the liquid can be modified as so
	# {{ topic | follow_topic_button : "Click to follow", "Click to unfollow" }}
	def follow_topic_button topic, follow_label = "Follow", unfollow_label = "Unfollow"
		if User.current
			_monitoring = !Monitorship.count(:id, 
							:conditions => ['user_id = ? and topic_id = ? and active = ?', 
							User.current.id, topic['id'], true]).zero?

			link_to _monitoring ? unfollow_label : follow_label, topic['toggle_follow_url'], 
				"data-remote" => true, "data-method" => :put, 
				:class => "btn btn-small #{_monitoring ? 'active' : ''}",
				"data-toggle" => "button",
				"data-button-active-label" => unfollow_label, 
				"data-button-inactive-label" => follow_label
		end
	end

	# Ticket specific helpers
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
	        if (field.field_type == "default_status" and in_portal)
	          element = label + content_tag(:div, 
	          		select(object_name, field_name,  
	          			field.field_type == "default_status" ? field.visible_status_choices : field.choices, 
	          			{:selected => field_value}, {:class => element_class}), :class => "controls")
	        end
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

end
