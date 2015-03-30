# encoding: utf-8
module SupportHelper
	include Portal::PortalFilters
  include Redis::RedisKeys
  include Redis::PortalRedis
  include Portal::Helpers::DiscussionsHelper
  include Portal::Helpers::Article

  # TODO-RAILS3 the below helpers are added to use liquids truncate
  # HACK Need to scope down liquid helpers and include only the required ones 
  # and ignore all rails helpers in portal_view
  include Liquid::StandardFilters

	FONT_INCLUDES = { "Source Sans Pro" => "Source+Sans+Pro:regular,italic,700,700italic",
					  "Droid Sans" => "Droid+Sans:regular,700",
					  "Lato" => "Lato:regular,italic,900,900italic",
					  "Arvo" => "Arvo:regular,italic,700,700italic",
					  "Droid Serif" => "Droid+Serif:regular,italic,700,700italic",
					  "Oswald" => "Oswald:regular,700",
					  "Open Sans Condensed" => "Open+Sans+Condensed:300,300italic,700",
					  "Open Sans" => "Open+Sans:regular,italic,700,700italic&subset=latin,latin-ext",
					  "Merriweather" => "Merriweather:regular,700",
					  "Roboto Condensed" => "Roboto+Condensed:regular,italic,700,700italic",
					  "Roboto" => "Roboto:regular,italic,700,700italic",
					  "Varela Round" => "Varela+Round:regular",
					  # "Helvetica Neue" => "Helvetica+Neue:regular,italic,700,700italic"
					}

	def time_ago(date_time)
		%( <span class='timeago' title='#{short_day_with_time(date_time)}' data-timeago='#{date_time}' data-livestamp='#{date_time}'>
			#{distance_of_time_in_words_to_now date_time} #{I18n.t('date.ago')}
		   </span> ).html_safe unless date_time.nil?
	end

	def short_day_with_time(date_time)
		formated_date(date_time,{:include_year => true})
	end

	def formated_date(date_time, options={})
	    default_options = {
	      :format => :short_day_with_time,
	      :include_year => false,
	      :translate => true
	    }
	    options = default_options.merge(options)
	    time_format = Account.current.date_type(options[:format])
	    unless options[:include_year]
	      time_format = time_format.gsub(/,\s.\b[%Yy]\b/, "") if (date_time.year == Time.now.year)
	    end
	    final_date = options[:translate] ? (I18n.l date_time , :format => time_format) : (date_time.strftime(time_format))
	end
  
  def default_meta meta
    output = []
    output << %( 
      <meta charset="utf-8" />
      <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1" />

      <meta name="description" content="#{ meta['description'] }" />
      <meta name="author" content="#{ meta['author'] }" /> )
      
    output << %( <meta name="keywords" content="#{ meta['keywords'] }" /> ) if meta['keywords'].present?
    output << %( <link rel="canonical" href="#{ meta['canonical'] }" /> ) if meta['canonical'].present?
      
    output.join('')
  end
  
  def default_responsive_settings portal
    if( portal['settings']['nonResponsive'] != "true" )
      %(<link rel="apple-touch-icon" href="/assets/touch/touch-icon-iphone.png" />
    	  <link rel="apple-touch-icon" sizes="72x72" href="/assets/touch/touch-icon-ipad.png" />
        <link rel="apple-touch-icon" sizes="114x114" href="/assets/touch/touch-icon-iphone-retina.png" />
    	  <link rel="apple-touch-icon" sizes="144x144" href="/assets/touch/touch-icon-ipad-retina.png" />
    	  <meta name="viewport" content="width=device-width, user-scalable=no, initial-scale=1.0" /> )
    end
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

		output.join(" ").html_safe
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
			if portal['can_signup_feature']
				output << content_tag(:div, 
															I18n.t('portal.login_signup_to_submit_ticket', 
																			:login_url => portal['login_url'], 
																			:signup_url => portal['signup_url']).html_safe, 
															:class => "hide-in-mobile")
			else
				output << content_tag(:div, 
															I18n.t('portal.login_to_submit_ticket', 
																			:login_url => portal['login_url']).html_safe, 
															:class => "hide-in-mobile")
			end
		end
		output << %(	<div>
							<a href="#{ portal['tickets_home_url'] }" class="mobile-icon-nav-status check-status ellipsis">
								<span>#{ I18n.t('header.check_ticket_status') }</span>
							</a>
						</div> )
		output << %( <div> <a href="#" class="mobile-icon-nav-contact contact-info ellipsis">
						<span>#{ h(portal['contact_info']) }</span>
					 </a> </div> ) if portal['contact_info']

		output << %(</nav>)
		output.join(" ").html_safe
	end

	# Portal tab navigation
	def portal_navigation portal
		output = []
		output << %( <nav class="page-tabs"> )
		if(portal['tabs'].present?)
			output << %(<div class="nav-link" id="header-tabs">)
			portal['tabs'].each do |tab|
				active_class = (tab['tab_type'] == portal['current_tab']) ? "active" : ""
				output << %( <a href="#{tab['url']}" class="#{active_class}">#{tab['label']}</a>) if(tab['url'])
			end
			output << %(</div>)
		end
		output << %(</nav>)
		output.join("").html_safe
	end

	# Portal header
	def facebook_header portal
		output = []
		output << %(
			<header class="banner">
				<div class="banner-wrapper">
					<div class="banner-title">
						#{ logo portal }
						<h1 class="ellipsis heading">#{ h(portal['name'])}</h1>
					</div>
				</div>
			</header>
			<nav class="page-tabs" >
				<div class="nav-link" id="header-tabs">
			)
		portal['tabs'].each do |tab|
			active_class = (tab['tab_type'] == portal['current_tab']) ? "active" : ""
			output << %( <a href="#{tab['url']}" class="#{active_class}"> #{h(tab['label'])}</a>) if(tab['url'])
		end
		user_class = portal['user'] ? "" : "no_user_ticket"
		output << %(
				</div>
			</nav>
			)
		output << %(
			<!-- <a href="#{ new_support_ticket_path }" class="facebook-button new_button #{user_class}" id="new_support_ticket">
				New support Ticket</a> -->
			<section>
					<div class="hc-search-c">
						<h2 class="">#{ I18n.t('header.help_center') }</h2>
						<form class="hc-search-form" autocomplete="off" action="#{ tab_based_search_url }" id="hc-search-form">
							<div class="hc-search-input">
								<input placeholder="#{ I18n.t('portal.search.placeholder') }" type="text"
									name="term" class="special" value="#{params[:term]}"
						            rel="page-search" data-max-matches="10">
						        <span class="search-icon icon-search-dark"></span>
							</div>
						</form>
					</div>
			</section> )

		output.join("").html_safe
	end

	# User image page
	def profile_image user, more_classes = "", width = "50px", height = "50px"
		output = []
		output << %( 	<div class="user-pic-thumb image-lazy-load #{more_classes}">
							<img src="/assets/misc/profile_blank_thumb.gif" onerror="imgerror(this)" )
		output << %(			data-src="#{user['profile_url']}" rel="lazyloadimage" ) if user['profile_url']
		output << %(			width="#{width}" height="#{height}" />
						</div> )
		output.join("").html_safe
	end

	#freshfone audio dom
	# TODO-RAILS3 duplicate of tickets_helper
 def freshfone_audio_dom(notable)
      notable = notable
      call = notable.freshfone_call
      dom = []
      if call.present? && call.recording_url
        dom << %(<br> <span> <b> #{I18n.t('freshfone.ticket.recording') }</b> </span>)
        if call.recording_audio
        	dom << %(<div class='freshfoneAudio'> <div class='ui360'> <a href=/helpdesk/attachments/#{call.recording_audio.id} type='audio/mp3' class='call_duration' data-time=#{call.call_duration} ></a>)
        else
          dom << %(<br> <div class='freshfoneAudio_text'>#{I18n.t('freshfone.recording_on_process')}</div>)
        end
      end
		dom.join("").html_safe
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
		_output << %(<a href='#{portal['linkback_url']}' class='portal-logo'>)
		# Showing the customer uploaded logo or default logo within an image tag
		_output << %(<span class="portal-img"><i></i>
										<img src='#{portal['logo_url']}' alt="#{I18n.t('logo')}"
										 		onerror="default_image_error(this)" data-type="logo" />
								 </span>)
		_output << %(</a>)
		_output.to_s.html_safe
	end

	def portal_fav_ico
		fav_icon = MemcacheKeys.fetch(["v7","portal","fav_ico",current_portal],30.days.to_i) do
     			current_portal.fav_icon.nil? ? '/assets/misc/favicon.ico?123458' :
            		AwsWrapper::S3Object.url_for(current_portal.fav_icon.content.path,
            			current_portal.fav_icon.content.bucket_name,
                        :expires => 30.days.to_i,
                        :secure => true)
            end
		"<link rel='shortcut icon' href='#{fav_icon}' />".html_safe
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

	def link_to_folder_with_count folder, *args
		link_opts = link_args_to_options(args)
		label = " #{h(folder['name'])} <span class='item-count'>#{folder['articles_count']}</span>".html_safe
		content_tag :a, label, { :href => folder['url'], :title => h(folder['name']) }.merge(link_opts)
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
		_text << I18n.t('since_time', :time_words => timediff_in_words(Time.now() - ticket['status_changed_on']))
		_text << %( <a href='#reply-to-ticket' data-proxy-for='#add-note-form'
			data-show-dom='#reply-to-ticket'>#{ t('portal.tickets.reopen_reply') }</a> ) if ticket['closed?']
		content_tag :div, _text.join(" ").html_safe, :class => "alert alert-ticket-status"
	end

	def widget_prefilled_value field
		format_prefilled_value(field, prefilled_value(field)) unless params[:helpdesk_ticket].blank?
	end

	def prefilled_value field
		if field.is_default_field?
			return URI.unescape(params[:helpdesk_ticket][field.name] || "")

		elsif params[:helpdesk_ticket][:custom_field].present?
			return nested_field_prefilled_value(field) if field.field_type == 'nested_field'
			return URI.unescape(params[:helpdesk_ticket][:custom_field][field.name] || "")
		end
	end

	def format_prefilled_value field, value
		return value.to_i if ['priority', 'status', 'group', 'agent'].include?(field.name)
		return (value.to_i == 1 || value.to_s == 'true') if (field.dom_type || field['dom_type']) == 'checkbox'
		value
	end

	def nested_field_prefilled_value field
		form_value = {}
		field.nested_levels.each do |ff|
			form_value[(ff[:level] == 2) ? :subcategory_val : :item_val] = URI.unescape(params[:helpdesk_ticket][:custom_field][ff[:name]] || "")
		end
		form_value.merge!({:category_val => URI.unescape(params[:helpdesk_ticket][:custom_field][field.name] || "") })
	end

	def ticket_field_container form_builder,object_name, field, field_value = ""
		case field.dom_type
			when "checkbox" then
				required = (field[:required_in_portal] && field[:editable_in_portal])
				%(  <div class="controls">
						<label class="checkbox #{required ? 'required' : '' }">
							#{ ticket_form_element form_builder,:helpdesk_ticket, field, field_value } #{ field[:label_in_portal] }
						</label>
					</div> ).html_safe
			else
				%( #{ ticket_label object_name, field }
		   			<div class="controls">

		   				#{ ticket_form_element form_builder,:helpdesk_ticket, field, field_value }
		   			</div> ).html_safe
		end
	end

	def ticket_label object_name, field
		required = (field[:required_in_portal] && field[:editable_in_portal])
		element_class = " #{required ? 'required' : '' } control-label #{field[:name]}-label"
		label_tag "#{object_name}_#{field[:name]}", field[:label_in_portal].html_safe, :class => element_class
	end

	def ticket_form_element form_builder, object_name, field, field_value = "", html_opts = {}
	    dom_type = (field.field_type == "nested_field") ? "nested_field" : (field['dom_type'] || field.dom_type)
	    required = (field.required_in_portal && field.editable_in_portal)
	    element_class = " #{required ? 'required' : '' } #{ dom_type }"
	    field_name      = (field_name.blank?) ? field.field_name : field_name
	    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }"

	    case dom_type
	      when "requester" then
	      	render(:partial => "/support/shared/requester", :locals => { :object_name => object_name, :field => field, :html_opts => html_opts, :value => field_value })
	      when "widget_requester" then
	      	render(:partial => "/support/shared/widget_requester", :locals => { :object_name => object_name, :field => field, :html_opts => html_opts, :value => field_value })
	      when "text", "number", "decimal" then
			text_field(object_name, field_name, { :class => element_class + " span12", :value => field_value }.merge(html_opts))
	      when "paragraph" then
			text_area(object_name, field_name, { :class => element_class + " span12", :value => field_value, :rows => 6 }.merge(html_opts))
	      when "dropdown" then
          	select(object_name, field_name,
          			field.field_type == "default_status" ? field.visible_status_choices : field.html_unescaped_choices,
          			{ :selected => (field.is_default_field? and is_num?(field_value)) ? field_value.to_i : field_value }, {:class => element_class})
	      when "dropdown_blank" then
	        select(object_name, field_name, field.html_unescaped_choices,
	        		{ :include_blank => "...", :selected => (field.is_default_field? and is_num?(field_value)) ? field_value.to_i : field_value }, {:class => element_class})
	      when "nested_field" then
			nested_field_tag(object_name, field_name, field,
	        	{:include_blank => "...", :selected => field_value},
	        	{:class => element_class}, field_value, true, required)
	      when "hidden" then
			hidden_field(object_name , field_name , :value => field_value)
	      when "checkbox" then
	      	( required ? check_box_tag(%{#{object_name}[#{field_name}]}, 1, !field_value.blank?, { :class => element_class } ) :
                                                   check_box(object_name, field_name, { :class => element_class, :checked => field_value.to_s.to_bool }) )
	      when "html_paragraph" then
	      	_output = []
	      	form_builder.fields_for(:ticket_body, @ticket.ticket_body) do |ff|
	      		element_class = " #{required ? 'required_redactor' : '' } #{ dom_type }"
	      		_output << %( #{ ff.text_area(field_name,
	      			{ :class => element_class + " span12", :value => field_value, :rows => 6 }.merge(html_opts)) } )
	      	end
	      	_output << %( #{ render(:partial=>"/support/shared/attachment_form") } )
	        # element = content_tag(:div, _output.join(" "), :class => "controls")
	      	# %( #{ text_area(object_name, field_name, { :class => element_class + " span12", :value => field_value, :rows => 6 }.merge(html_opts)) }
	      	   #{ render(:partial=>"/support/shared/attachment_form") } )
	    end
	end

	# The field_value(init value) for the nested field should be in the the following format
	# { :category_val => "", :subcategory_val => "", :item_val => "" }
	def nested_field_tag(_name, _fieldname, _field, _opt = {}, _htmlopts = {}, _field_values = {}, in_portal = false, required)
		_category = select(_name, _fieldname, _field.html_unescaped_choices, _opt, _htmlopts)
		_javascript_opts = {
		  :data_tree => _field.nested_choices,
		  :initValues => _field_values,
		  :disable_children => false
		}.merge!(_opt)

		_field.nested_levels.each do |l|
		  _javascript_opts[(l[:level] == 2) ? :subcategory_id : :item_id] = (_name +"_"+ l[:name]).gsub('[','_').gsub(']','')
		  _category += content_tag :div, content_tag(:label, (l[(!in_portal)? :label : :label_in_portal]).html_safe, :class => "#{required ? 'required' : '' }") + select(_name, l[:name], [], _opt, _htmlopts), :class => "level_#{l[:level]}"
		end

		_category + javascript_tag("jQuery('##{(_name +"_"+ _fieldname).gsub('[','_').gsub(']','')}').nested_select_tag(#{_javascript_opts.to_json});")
	end

	# NON-FILTER HELPERS
	# Search url for different tabs
	def tab_based_search_url
		current_filter = defined?(@search) ? @search.current_filter.to_s : @current_tab
		case current_filter
			when 'tickets'
				tickets_support_search_path
			when 'solutions'
				solutions_support_search_path
			when 'forums','topics'
				topics_support_search_path
			else
				support_search_path
		end
	end

	# Including google font for portal
	def include_google_font *args
		font_url = args.uniq.map { |f| FONT_INCLUDES[f] }.reject{ |c| c.nil? }
		unless font_url.blank?
			"<link href='https://fonts.googleapis.com/css?family=#{font_url.join("|")}' rel='stylesheet' type='text/css'>".html_safe
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

	def default_ticket_list_item ticket
		label_class_name = ticket['active?'] ? "label-status-pending" : "label-status-closed"

		unless ticket['requester'] or User.current.eql?(ticket['requester'])
			time_ago_text = I18n.t('ticket.fb_portal_created_on', { :username => h(ticket['requester']['name']), :date => time_ago(ticket['created_on']) })
		else
			time_ago_text = I18n.t('ticket.fb_portal_created_on_same_user', { :date => time_ago(ticket['created_on']) })
		end
		unless ticket['freshness'] == "new"
			unique_agent = "#{I18n.t("ticket.assigned_agent")} : <span class='emphasize'> #{ h(ticket['agent']) }</span>"
		end

		%( <div class="c-row c-ticket-row">
			<span class="status-source sources-detailed-#{ ticket['source_name'].downcase }"> </span>
			<span class="#{label_class_name} label label-small">
				#{ ticket['status'] }
			</span>
			<div class="ticket-brief">
				<div class="ellipsis">
					<a href="#{ ticket['current_portal']['facebook_portal'] ? ticket['full_domain_url'] : ticket['portal_url'] }" class="c-link" title="#{ h(ticket.description_text) }">
						#{ h(ticket['subject']) } ##{ ticket['id'] }
					</a>
				</div>
				<div class="help-text">
					#{ time_ago_text }
					#{ unique_agent }
				</div>
			</div>
		</div> ).html_safe
	end

	# Portal placeholders to access dynamic data inside javascripts
	def portal_access_varibles
		output = []
		output << %( <script type="text/javascript"> )
		output << %(  	var portal = #{portal_javascript_object}; )
		output << %( </script> )
		output.join("").html_safe
	end

	def portal_javascript_object
		{ :language => @portal['language'],
		  :name => h(@portal['name']),
		  :contact_info => h(@portal['contact_info']),
		  :current_page_name => @current_page_token,
		  :current_tab => @current_tab,
		  :preferences => portal_preferences,
			:image_placeholders => { 	:spacer 		=> spacer_image_url,
			 							:profile_thumb 	=> "#{asset_host_url}/assets/misc/profile_blank_thumb.gif",
										:profile_medium => "#{asset_host_url}/assets/misc/profile_blank_medium.gif" }
		}.to_json
	end

	def portal_copyright portal
		%( 	<div class="copyright">
				<a href="http://www.freshdesk.com" target="_blank"> #{ I18n.t('footer.helpdesk_software') } </a>
				#{ I18n.t('footer.by_freshdesk') }
			</div> ) unless portal.paid_account
	end

	def link_to_cookie_law portal
		%(	<a href="#portal-cookie-info" rel="freshdialog" data-lazy-load="true" class="cookie-link"
				data-width="450px" title="#{ I18n.t('portal.cookie.why_we_love_cookies') }" data-template-footer="">
				#{ I18n.t('portal.cookie.cookie_policy') }
			</a> #{ cookie_law } ).html_safe
	end

	def link_to_privacy_policy portal
		%(	<a href="http://freshdesk.com/privacy" target="_blank" class="privacy-link">
				#{ I18n.t('portal.cookie.privacy_policy') }
			</a>) if(!portal.paid_account && ["user_signup", "user_login", "submit_ticket", "profile_edit"].include?(portal['current_page']))
	end

	def cookie_law
		privacy_link = %(<a href="http://freshdesk.com/privacy/" target="_blank">#{ I18n.t('portal.cookie.privacy_policy') }</a>)
		%(<div id="portal-cookie-info" class="hide"><textarea>
				<p>#{ I18n.t('portal.cookie.cookie_dialog_info1') }</p>
				<p>#{ I18n.t('portal.cookie.cookie_dialog_info2', :privacy_link => privacy_link) }</p>
				<p>#{ I18n.t('portal.cookie.cookie_dialog_info3', :privacy_link => privacy_link) }</p>
			</textarea></div>).html_safe
	end

	def widget_option type
		true
	end

	def helpdesk_ticket_values(field,params = {})
		unless params.blank?
			params = params[:helpdesk_ticket]
			if params[:ticket_body_attributes] and params[:ticket_body_attributes][field.field_name]
				params[:ticket_body_attributes][field.field_name]
			elsif params[:custom_field] and params[:custom_field][field.field_name]
				if field.field_type == "nested_field"
					field_value = { :category_val => "#{params[:custom_field][field.field_name]}",
					                :subcategory_val => "#{params[:custom_field][field.nested_ticket_fields.first.field_name]}",
					                :item_val => "#{params[:custom_field][field.nested_ticket_fields.last.field_name]}" }
				else
					params[:custom_field][field.field_name]
			    end
			else
				params[field.field_name]
			end
    end
	end

	def is_num?(str)
		Integer(str || "")
	rescue ArgumentError
		false
	else
		true
	end

	def back_to_agent_view
    _output = []
    if @agent_actions.present? && current_user && current_user.agent?
      _output << %( <div class="helpdesk_view">)
      _output << %( <div class="agent_view"> <i class='icon-agent-actions'></i> </div> )
      _output << %( <div class="agent_actions hide">)
      _output << %( <div class="action_title">Agent Actions</div>)
      @agent_actions.each do |action|
        _output << %( <a class="agent_options" href="#{action[:url]}">
                        <i class='icon-agent-#{action[:icon]}'></i> #{action[:label]}
                    </a>)
      end
      _output << %( </div></div>)
    end
    _output.join("").html_safe
  end

	def ticket_attachemnts ticket
		output = []

		if(ticket.attachments.size > 0 or ticket.cloud_files.size > 0)
			output << %(<div class="cs-g-c attachments" id="ticket-#{ ticket.id }-attachments">)

			can_delete = (ticket.requester and (ticket.requester.id == User.current.id))

			(ticket.attachments || []).each do |a|
				output << attachment_item(a.to_liquid, can_delete)
			end
			(ticket.cloud_files || []).each do |c|
				output << cloud_file_item(c.to_liquid, can_delete)
			end

			output << %(</div>)
		end
		output.join('').html_safe
	end

	def comment_attachments comment
		output = []

		if(comment.attachments.size > 0 or comment.cloud_files.size > 0)
			output << %(<div class="cs-g-c attachments" id="comment-#{ comment.id }-attachments">)

			can_delete = (comment.user and comment.user.id == User.current.id)

			(comment.attachments || []).each do |a|
				output << attachment_item(a.to_liquid, can_delete)
			end

			(comment.cloud_files || []).each do |c|
				output << cloud_file_item(c.to_liquid, can_delete)
			end

			output << %(</div>)
		end
		output.join('').html_safe

	end

	def attachment_item attachment, can_delete = false
		output = []

		output << %(<div class="attachment">)
		output << %(<a href="#{attachment.delete_url}" data-method="delete" data-confirm="#{I18n.t('attachment_delete')}" class="delete mr5"></a>) if can_delete

		output << default_attachment_type(attachment)

		output << %(<div class="attach_content">)
		output << %(<div class="ellipsis">)
		output << %(<a href="#{attachment.url}" class="filename" target="_blank">#{ attachment.filename } </a>)
		output << %(</div>)
		output << %(<div>(#{  attachment.size  }) </div>)
		output << %(</div>)
		output << %(</div>)

		output.join('').html_safe
	end

	def cloud_file_item cloud_file, can_delete = false
		output = []

		output << %(<div class="attachment">)
		output << %(<a href="#{cloud_file.delete_url}" data-method="delete" data-confirm="#{I18n.t('attachment_delete')}" class="delete mr5"></a>) if can_delete

		output << %(<img src="/assets/#{cloud_file.provider}_big.png"></span>)

		output << %(<div class="attach_content">)
		output << %(<div class="ellipsis">)
		output << %(<a href="#{cloud_file.url}" class="filename" target="_blank">#{ cloud_file.filename } </a>)
		output << %(<span class="file-size cloud-file"></span>)
		output << %(</div>)
		output << %(</div>)
		output << %(</div>)

		output.join('').html_safe
	end

	def default_attachment_type (attachment)
		output = []

		if attachment.is_image?
			output << %(<img src="#{attachment.thumbnail}" onerror="default_image_error(this)" class="file-thumbnail image" alt="#{attachment.filename}">)
		else
	      	filetype = attachment.filename.split(".")[-1] || ""
	      	output << %(<div class="attachment-type">)
	      	if (filetype != "" && filetype.size <= 4)
	      		output << %(<span class="file-type"> #{ filetype } </span> )
	        else
	        	output << %( <span> </span> )
	        end
	      	output << %(</div>)
	    end

	    output.join('')
	end

	def page_tracker
		case @current_page_token
		when "topic_view"
			"<img src='#{hit_support_discussions_topic_path(@topic)}' />".html_safe
		when "article_view"
			"<img src='#{hit_support_solutions_article_path(@article)}' />".html_safe
		else
			""
		end
	end

	def spacer_image_url
		"#{asset_host_url}/assets/misc/spacer.gif"
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
		        !get_portal_redis_key(is_preview).blank? && !current_user.blank? && current_user.agent?
		    end
	    end

		def link_args_to_options(args)
	      link_opts = {}
	      [:label, :title, :id, :class, :rel].zip(args) {|key, value| link_opts[key] = h(value) unless value.blank?}
	      link_opts
	    end
end
