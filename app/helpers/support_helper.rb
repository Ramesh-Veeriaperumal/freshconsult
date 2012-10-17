module SupportHelper
	include ActionView::Helpers::TagHelper
	include ActionView::Helpers::DateHelper
	include ActionView::Helpers::UrlHelper
	
	# include ActionController::UrlWriter
    # default_url_options[:host] = Portal.current.portal_url

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
	def portal_render( local_file, db_file = "" )
		# render_to_string :partial => local_file, :locals => { :dynamic_template => db_file }
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

	def link_signup label
		link_to(label, "/support/registration/new", :class => "btn btn-signup") if Account.current.features? :signup_link
	end

	# def link_to_solutions label
	# 	_active_page_type = [:solution_home, :article_list, :article_view]
	# 	link_to(label, "/support/", :class => "abc")
	# end

	# Tab links
	# def link_to label
	# 	link_to(label, "/")
	# end

	# Portal new ticket form
	def construct_ticket_element(object_name, field, field_label, dom_type, required, field_value = "", field_name = "", in_portal = false , is_edit = false)
	    dom_type = (field.field_type == "nested_field") ? "nested_field" : dom_type
	    element_class   = " #{ (required) ? 'required' : '' } #{ dom_type }"
	    field_label    += " #{ (required) ? '<span class="required_star">*</span>' : '' }"
	    field_name      = (field_name.blank?) ? field.field_name : field_name
	    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }"
	    label = label_tag object_name+"_"+field.field_name, field_label, :class => "control-label"
	    case dom_type
	      when "requester" then
	        element = label + content_tag(:div, render(:partial => "/shared/autocomplete_email.html", :locals => { :object_name => object_name, :field => field, :url => autocomplete_helpdesk_authorizations_path, :object_name => object_name }))    
	        unless is_edit or params[:format] == 'widget'
	          element += add_requester_field 
	          element = add_cc_field_tag element, field
	        end
	      when "email" then
	        element = label + text_field(object_name, field_name, :class => element_class, :value => field_value)
	        element = add_cc_field_tag element ,field if (field.portal_cc_field? && !is_edit && controller_name.singularize != "feedback_widget") #dirty fix
	        element += add_name_field unless is_edit
	      when "text", "number" then
	        element = label + text_field(object_name, field_name, :class => element_class, :value => field_value)
	      when "paragraph" then
	        element = label + text_area(object_name, field_name, :class => element_class, :value => field_value)
	      when "dropdown" then
	        if (field.field_type == "default_status" and in_portal)
	          element = label + select(object_name, field_name, field.visible_status_choices, {:selected => field_value},{:class => element_class})
	        else
	          element = label + select(object_name, field_name, field.choices, {:selected => field_value},{:class => element_class})
	        end
	      when "dropdown_blank" then
	        element = label + select(object_name, field_name, field.choices, {:include_blank => "...", :selected => field_value}, {:class => element_class})
	      when "nested_field" then
	        element = label + nested_field_tag(object_name, field_name, field, {:include_blank => "...", :selected => field_value}, {:class => element_class}, field_value, in_portal)
	      when "hidden" then
	        element = hidden_field(object_name , field_name , :value => field_value)
	      when "checkbox" then
	        element = content_tag(:div, check_box(object_name, field_name, :class => element_class, :checked => field_value ) + label)
	      when "html_paragraph" then
	        element = label + text_area(object_name, field_name, :class => element_class +" mceEditor", :value => field_value)
	    end
	    content_tag :div, element, :class => dom_type + " control-group"
	end


end
