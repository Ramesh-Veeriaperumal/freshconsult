# encoding: utf-8
module SupportHelper
  include Portal::PortalFilters
  include Redis::RedisKeys
  include Redis::PortalRedis
  include Portal::Helpers::DiscussionsHelper
  include Portal::Helpers::DiscussionsVotingHelper
  include Portal::Helpers::Article
  include Portal::Helpers::SolutionsHelper
  include Cache::FragmentCache::Base
  include Portal::PreviewKeyTemplate

  # TODO-RAILS3 the below helpers are added to use liquids truncate
  # HACK Need to scope down liquid helpers and include only the required ones
  # and ignore all rails helpers in portal_view
  include Liquid::StandardFilters

	FONT_INCLUDES = { "Source Sans Pro" => "Source+Sans+Pro:regular,italic,600,700,700italic",
					  "Droid Sans" => "Droid+Sans:regular,700",
					  "Lato" => "Lato:regular,italic,700,900,900italic",
					  "Arvo" => "Arvo:regular,italic,700,700italic",
					  "Droid Serif" => "Droid+Serif:regular,italic,700,700italic",
					  "Oswald" => "Oswald:regular,700",
					  "Open Sans Condensed" => "Open+Sans+Condensed:300,300italic,700",
					  "Open Sans" => "Open+Sans:regular,italic,600,700,700italic",
					  "Merriweather" => "Merriweather:regular,700,900",
					  "Roboto Condensed" => "Roboto+Condensed:regular,italic,700,700italic",
					  "Roboto" => "Roboto:regular,italic,500,700,700italic",
					  "Varela Round" => "Varela+Round:regular",
					  "Poppins" => "Poppins:regular,600,700",
					  # "Helvetica Neue" => "Helvetica+Neue:regular,italic,700,700italic"
					}

  PORTAL_PREFERENCES_ESCAPE_ATTRIBUTES = ['baseFont', 'headingsFont']

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
      <meta name="description" content= "#{meta['description']}" />
      <meta name="author" content= "#{meta['author']}" />
      )
    output << og_meta_tags(meta) unless Account.current.hide_og_meta_tags_enabled?

    output << %( <meta name="keywords" content="#{ meta['keywords'] }" /> ) if meta['keywords'].present?
    output << %( <link rel="canonical" href="#{ meta['canonical'] }" /> ) if meta['canonical'].present?
    output << multilingual_meta_tags(meta['multilingual_meta']) if meta['multilingual_meta'].present?
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

    output << language_list(portal)

    # Showing welcome text before login link
    output << %(<div class="welcome">#{ t('header.welcome') })

    # Showing logged in user name or displaying as Guest
    output << %(<b>#{ h((portal['user']).to_s) || t('header.guest') }</b> </div> )

    # Showing portal login link or signout link based on user logged in condition
    if portal['user']
      # Show switch to agent portal if the loggedin user is an agent
      output << %(<b><a href="#{ portal['helpdesk_url']}">#{ t('header.goto_agent_portal') }</a></b>) if portal['user'].agent?
      # Showing profile settings path for loggedin user
      output << %(| <b><a href="#{ portal['profile_url'] }">#{ t('header.edit_profile') }</a></b>) unless Account.current.anonymous_account?
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
              <a href="#{ portal['new_ticket_url'] }" class="mobile-icon-nav-newticket new-ticket ellipsis" title="#{ I18n.t('header.new_support_ticket') }">
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
    output << %(  <div>
              <a href="#{ portal['tickets_home_url'] }" class="mobile-icon-nav-status check-status ellipsis" title="#{ I18n.t('header.check_ticket_status') }">
                <span>#{ I18n.t('header.check_ticket_status') }</span>
              </a>
            </div> )
    output << %( <div> <a href="tel:#{ h(portal['contact_info']) }" class="mobile-icon-nav-contact contact-info ellipsis">
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

  def agent_login_link
    if current_account.freshid_sso_sync_enabled? && (current_account.agent_custom_sso_enabled? || current_account.freshid_custom_policy_enabled?(:agent))
      Freshid::V2::UrlGenerator.url_with_query_params(
          current_account.agent_custom_login_url,
          { client_id: FRESHID_V2_CLIENT_ID, redirect_uri: freshid_authorize_callback_url }
      )
    elsif (current_account.agent_oauth2_sso_enabled? || current_account.agent_freshid_saml_sso_enabled? || current_account.agent_oidc_sso_enabled?)
      agent_login_url
    else
      current_account.freshid_enabled? ? Freshid::Config.login_url(freshid_authorize_callback_url, freshid_logout_url, {}) : Freshid::V2::UrlGenerator.login_url(freshid_authorize_callback_url, {})
    end
  end

  def customer_login_link
    if current_account.freshid_sso_sync_enabled? && (current_account.contact_custom_sso_enabled? || current_account.freshid_custom_policy_enabled?(:contact))
      Freshid::V2::UrlGenerator.url_with_query_params(
          Account.current.customer_custom_login_url,
          { client_id: FRESHID_V2_CLIENT_ID, redirect_uri: freshid_customer_authorize_callback_url }
      )
    else
      customer_login_url
    end
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
                <label class="">#{ I18n.t('portal.search.placeholder') }</label>
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
  def profile_image user, more_classes = "", width = "50px", height = "50px", profile_size = 'thumb'
    output = []
    output << %(  <div class="user-pic-thumb image-lazy-load #{more_classes}"> )
    if user.blank?
      output << %( <img src="/images/misc/profile_blank_thumb.jpg" onerror="imgerror(this)" class="#{profile_size}" />)
      Rails.logger.error("User is empty::Account:#{Account.current.inspect}")
    elsif user['profile_url']
      output << %( <img src="/images/misc/profile_blank_thumb.jpg" onerror="imgerror(this)" class="#{profile_size}" rel="lazyloadimage"  data-src="#{user['profile_url']}" /> )
    else
      username = user['name']
      username = username.lstrip if username
      output << default_profile_image(username, profile_size)
    end
    output << %( </div> )
    output.join("").html_safe
  end

  def email_name_profile_image(username, profile_size = 'thumb')
    %( <div class="user-pic-thumb image-lazy-load user-pointer-bottom"> #{default_profile_image(username, profile_size)} </div> ).html_safe
  end

  def default_profile_image(username, profile_size = 'thumb')
    output = []
    if username && username[0] && isalpha(username[0])
      output << %(<div class="#{profile_size} avatar-text circle text-center bg-#{unique_code(username)}">)
      output << %( #{username[0]} )
      output << %( </div>)
    else
      output << %( <img src="/images/misc/profile_blank_thumb.jpg" onerror="imgerror(this)" class="#{profile_size}" />)
      Rails.logger.error("Showing blank profile thumbnail for User: #{username} Account:#{Account.current.id}")
    end
    output.join('')
  end

  #user avatar for canned form preview
  def preview_profile_image
    output = []
    output << %(  <div class="user-pic-thumb image-lazy-load"> )
    output << %( <img src="/images/misc/profile_blank_thumb.jpg" onerror="imgerror(this)" class="preview_image" rel="lazyloadimage"  }" /> )
    output << %( </div> )
    output.join("").html_safe
  end

  def filler_for_solutions portal
    %( <div class="no-results">#{ I18n.t('portal.no_articles_info_1') }</div>
       <div class="no-results">#{ I18n.t('portal.no_articles_info_2') }</div> )
  end

  def filler_for_folders folder
    %( <div class="no-results">#{ I18n.t('portal.folder.filler_text', :folder_name => h(folder['name'])) }</div> )
  end

  # Logo for the portal
  def logo portal, link_flag = false
    _output = []
    _output << %(<a href="#{ link_flag ?  "javascript:void(0)" : "#{portal['linkback_url']}" }")
    _output << %(class='portal-logo'>)
    # Showing the customer uploaded logo or default logo within an image tag
    _output << %(<span class="portal-img"><i></i>
                    <img src='#{portal['logo_url']}' alt="#{I18n.t('logo')}"
                        onerror="default_image_error(this)" data-type="logo" />
                 </span>)
    _output << %(</a>)
    _output.to_s.html_safe
  end

  def portal_fav_ico
    fav_icon = current_portal.fetch_fav_icon_url
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
    _text << %( <b> #{ticket['status']} | </b> )
    _text << time_ago(ticket['status_changed_on'])
    _text << %( <a href='#reply-to-ticket' data-proxy-for='#add-note-form'
      data-show-dom='#reply-to-ticket'>#{ t('portal.tickets.reopen_reply') }</a> ) if ticket['closed?']
    content_tag :div, _text.join(" ").html_safe, :class => "alert alert-ticket-status"
  end

  def archive_status_alert ticket
    _text = []
    _text << I18n.t('archive_ticket.no_reply_msg')
    content_tag :div, _text.join(" ").html_safe, :class => "alert alert-ticket-status"
  end

  def widget_prefilled_value field
    #format_prefilled_value(field, prefilled_value(field)) unless params[:helpdesk_ticket].blank?
    if @feeback_widget_error
      helpdesk_ticket_values field, @params
    else
      format_prefilled_value(field, prefilled_value(field)) unless params[:helpdesk_ticket].blank?
    end
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
    custom_fields = params[:helpdesk_ticket][:custom_field]
    field.nested_levels.each do |ff|
      value = URI.unescape(custom_fields[ff[:name]] || "")
      form_value[(ff[:level] == 2) ? :subcategory_val : :item_val] = RailsSanitizer.full_sanitizer.sanitize(value)
    end
    category_val = URI.unescape(custom_fields[field.name] || "")
    form_value.merge!({:category_val => RailsSanitizer.full_sanitizer.sanitize(category_val) })
  end

  def ticket_field_container form_builder,object_name, field, field_value = "", pl_value_id=nil, html_opts_hash = {}
    html_opts_hash[:pre_fill_flag] = true if html_opts_hash[:pre_fill_flag].nil?
    case field.dom_type
      when "checkbox" then
        required = (field[:required_in_portal] && field[:editable_in_portal])
        %(  <div class="controls">
            <label class="checkbox #{required ? 'required' : '' }">
              #{ ticket_form_element form_builder,:helpdesk_ticket, field, field_value, { :pl_value_id => pl_value_id } } #{ field.translated_label_in_portal.html_safe }
            </label>
          </div> ).html_safe
      else
        html_opts_hash[:pl_value_id] = pl_value_id
        html_opts_hash.delete(:pre_fill_flag) if field.dom_type != "requester"
        %( #{ ticket_label object_name, field }
            <div class="controls #{"nested_field" if field.dom_type=="nested_field"} #{"support-date-field" if field.dom_type=="date"} #{"company_div" if field.field_type == "default_company" && @ticket.new_record?}">
              #{ ticket_form_element form_builder, :helpdesk_ticket, field, field_value,html_opts_hash}
            </div> ).html_safe
    end
  end

  def ticket_label object_name, field
    required = (field[:required_in_portal] && field[:editable_in_portal])
    element_class = " #{required ? 'required' : '' } control-label #{field[:name]}-label #{"company_label" if field.field_type == "default_company" && @ticket.new_record?}"
    # adding :for attribute for requester(as email) element => to enable accessability
    if field[:name] == "requester"
      label_tag "#{object_name}_#{field[:name]}", field.translated_label_in_portal.html_safe, :class => element_class, :for => "#{object_name}_email"
    elsif field.respond_to?(:encrypted_field?) && field.encrypted_field?
      label_tag "#{object_name}_#{field[:name]}",
                content_tag(:span, "", :class => "ficon-encryption-lock encrypted", :title => t('custom_fields.encrypted_text'), 'data-toggle' => 'tooltip', 'data-placement' => 'top' ) +
                " #{field[:label_in_portal].html_safe}", :class => element_class, :for => "#{object_name}_email"
    elsif field.respond_to?(:secure_field?) && field.secure_field?
      label_tag "#{object_name}_#{field[:name]}",
                content_tag(:span, '', :class => 'ficon-encryption-lock encrypted', :title => t('custom_fields.encrypted_text'), 'data-toggle' => 'tooltip', 'data-placement' => 'top') +
                " #{field.label_in_portal.html_safe}", :class => element_class, :for => "#{object_name}_email"
    else
      label_tag "#{object_name}_#{field[:name]}", field.translated_label_in_portal.html_safe, :class => element_class
    end
  end

  def ticket_form_element form_builder, object_name, field, field_value = "", html_opts = {}
      pl_value_id = html_opts.delete(:pl_value_id)

      dom_type = (field.field_type == "nested_field") ? "nested_field" : (field['dom_type'] || field.dom_type)
      required = (field.required_in_portal && field.editable_in_portal)
      element_class   = " #{required ? 'required' : '' } #{ dom_type }"
      element_class  += " section_field" if field.section_field?
      element_class += " dynamic_sections" if field.section_dropdown?
      field_name      = (field_name.blank?) ? field.field_name : field_name
      object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }"
      case dom_type
        when "requester" then
          @company_cc_in_portal = field.company_cc_in_portal?
          render(:partial => "/support/shared/requester", :locals => { :object_name => object_name, :field => field, :html_opts => html_opts, :value => field_value })
        when "widget_requester" then
          render(:partial => "/support/shared/widget_requester", :locals => { :object_name => object_name, :field => field, :html_opts => html_opts, :value => field_value })
        when "text", "number", "decimal" then
          text_field(object_name, field_name, { :class => element_class + " span12", :value => field_value }.merge(html_opts))
        when "encrypted_text" then
          text_field(object_name, field_name, { :class => element_class + " span12 ficon-encrypted_text encrypted-text-field", :value => field_value }.merge(html_opts))
        when "paragraph" then
          text_area(object_name, field_name, { :class => element_class + " span12", :value => field_value, :rows => 6 }.merge(html_opts))
        when 'secure_text' then
          render(partial: '/support/shared/secure_field', :locals => { :prefix => PciConstants::PREFIX, :object_name => object_name, :field_name => field_name, :html_opts => html_opts, :value => field_value })
        when "dropdown" then
            select(object_name, field_name,
                field.field_type == "default_status" ? field.visible_status_choices : field.html_unescaped_choices(nil, true),
                { :selected => (field.is_default_field? and is_num?(field_value)) ? field_value.to_i : field_value }, {:class => element_class})
        when "dropdown_blank" then
          tkt = @ticket if field.field_type == "default_company"
          choices = field.html_unescaped_choices(tkt, true)
          disabled = true if field.field_type == "default_company" && choices.empty?
          select(object_name, field_name, choices,
              { :include_blank => "...", :selected => (field.is_default_field? and is_num?(field_value)) ? field_value.to_i : field_value }, {:class => element_class, :disabled => disabled})
        when "nested_field" then
          nested_field_tag(object_name, field_name, field,
            {:include_blank => "...", :selected => field_value, :pl_value_id => pl_value_id},
            {:class => element_class}, field_value, true, required)
        when "hidden" then
          hidden_field(object_name , field_name , :value => field_value)
        when "checkbox" then
          check_box_html = { :class => element_class }
          if pl_value_id
            id = gsub_id object_name+"_"+field_name+"_"+pl_value_id
            check_box_html.merge!({:id => id})
          end
          ( required ? check_box_tag(%{#{object_name}[#{field_name}]}, 1, !field_value.blank?, check_box_html ) :
                                                   check_box(object_name, field_name, check_box_html.merge!({:checked => field_value.to_s.to_bool})) )
        when "date" then
          construct_date_field(field_value, object_name, field_name, element_class)
        when "html_paragraph" then
          _output = []
          form_builder.fields_for(:ticket_body, @ticket.ticket_body) do |ff|
            element_class = " #{required ? 'required_redactor' : '' } #{ dom_type }"
            _output << %( #{ ff.text_area(field_name,
              { :class => element_class + " span12", :value => field_value, :rows => 6 }.merge(html_opts)) } )
          end
          if(@widget_form)
            _output << %( #{ render(:partial=>"/support/shared/widget_attachment_form") } )
          else
            _output << %( #{ render(:partial=>"/support/shared/attachment_form") } )
          end
          # element = content_tag(:div, _output.join(" "), :class => "controls")
          # %( #{ text_area(object_name, field_name, { :class => element_class + " span12", :value => field_value, :rows => 6 }.merge(html_opts)) }
             #{ render(:partial=>"/support/shared/attachment_form") } )
      end
  end

  def construct_canned_form(object_name, field, disabled = false)
    dom_type = field[:name].split('_')[0]
    return unless Admin::CannedForm::CUSTOM_FIELDS_SUPPORTED.include? dom_type.to_sym
    form_builder = Admin::CannedForm::Constructor.new(field: field, object_name: object_name, disabled: disabled)
    element = form_builder.safe_send("#{dom_type}_element")
    safe_join(element)
  end

  def render_add_cc_field  field, condition
          render(:partial => "/support/shared/add_cc_field", :locals => { :field => field, :_cc_condition => condition })
  end

  def fragment_cache_dom_options form_builder
    cache_options = {
      :cc_container => '',
      :company_container => '',
      :company_cache_condition => false,
      :cc_cache_condition => false
    }
    if Account.current.launched?(:support_new_ticket_cache) && current_user.present?
      cache_options[:company_cache_condition] = Account.current.multiple_user_companies_enabled? &&
        (current_user.present? || current_user.agent? || current_user.contractor?)
      if cache_options[:company_cache_condition]
        company_field = Account.current.ticket_fields.default_company_field.first
        cache_options[:company_container] = ticket_field_container(form_builder, :helpdesk_ticket, company_field, helpdesk_ticket_values(company_field,@params)).html_safe
      end
      requester_field = Account.current.ticket_fields.requester_field.first
      cache_options[:cc_cache_condition] = current_user.present? && requester_field.portal_cc_field? && ( current_user.company.present? || requester_field.all_cc_in_portal? || current_user.contractor? )
      cache_options[:cc_container] = render_add_cc_field(requester_field, cache_options[:cc_cache_condition]).html_safe if cache_options[:cc_cache_condition]
    end
    cache_options
  end

  # The field_value(init value) for the nested field should be in the the following format
  # { :category_val => "", :subcategory_val => "", :item_val => "" }
  def nested_field_tag(_name, _fieldname, _field, _opt = {}, _htmlopts = {}, _field_values = {}, in_portal = false, required)
    _javascript_opts = {
      :data_tree => _field.translated_nested_choices,
      :initValues => _field_values,
      :disable_children => false
    }.merge!(_opt)
    if _opt[:pl_value_id].present?
      _htmlopts.merge!({:id => gsub_id("#{_name}_#{_fieldname}_#{_opt[:pl_value_id]}")})
      _category = select(_name, _fieldname, _field.html_unescaped_choices(nil, true), _opt, _htmlopts)

      _field.nested_levels.each do |l|
        _htmlopts.merge!({:id => gsub_id("#{_name}_#{l[:name]}_#{_opt[:pl_value_id]}")})
        _javascript_opts[(l[:level] == 2) ? :subcategory_id : :item_id] = gsub_id(_name +"_"+ l[:name]+"_"+_opt[:pl_value_id])
        _category += content_tag :div, content_tag(:label, (l[(!in_portal)? :label : :label_in_portal]).html_safe, :class => "#{required ? 'required' : '' }") + select(_name, l[:name], [], _opt, _htmlopts), :class => "level_#{l[:level]}"
      end

      (_category + javascript_tag("jQuery('##{gsub_id(_name +"_"+ _fieldname+"_"+_opt[:pl_value_id])}').nested_select_tag(#{_javascript_opts.to_json});"))
    else
      _category = select(_name, _fieldname, _field.html_unescaped_choices(nil, true), _opt, _htmlopts)

      _field.nested_levels.each do |l|
        _javascript_opts[(l[:level] == 2) ? :subcategory_id : :item_id] = gsub_id(_name +"_"+ l[:name])
        _category += content_tag :div, content_tag(:label, (l[(!in_portal)? :label : :label_in_portal]).html_safe, :class => "#{required ? 'required' : '' }") + select(_name, l[:name], [], _opt, _htmlopts), :class => "level_#{l[:level]}"
      end

      _category + javascript_tag("jQuery('##{gsub_id(_name +"_"+ _fieldname)}').nested_select_tag(#{_javascript_opts.to_json});")
    end
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
    _field_value = (field.is_default_field?) ? ticket.safe_send(field.field_name) : fetch_custom_field(ticket, field.name)
    _dom_type = (_field_type == "default_source") ? "dropdown" : field.dom_type

    case _dom_type
      when "dropdown", "dropdown_blank"
          if(_field_type == "default_agent")
          ticket.responder.name if ticket.responder
          elsif(_field_type == "nested_field" || _field_type == "nested_child")
          fetch_custom_field(ticket, field.name)
          else
          field.dropdown_selected(((_field_type == "default_status") ?
            field.all_status_choices : field.html_unescaped_choices(nil, true)), _field_value)
          end
      when "checkbox"
        _field_value ? I18n.t('plain_yes') : I18n.t('plain_no')
      when "date"
        formatted_date(_field_value) if _field_value.present?
      else
          _field_value
    end
  end

  def ticket_field_form_value(field, ticket)
    form_value = (field.is_default_field?) ?
                  ticket.safe_send(field.field_name) : fetch_custom_field(ticket, field.name)

    if(field.field_type == "nested_field")
      form_value = {}
      field.nested_levels.each do |ff|
      form_value[(ff[:level] == 2) ? :subcategory_val : :item_val] = fetch_custom_field(ticket, ff[:name])
      end
      form_value.merge!({:category_val => fetch_custom_field(ticket, field.name)})
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
    output << %(    var portal = #{portal_javascript_object}; )
    output << %(    var attachment_size = #{attachment_size}; )
    output << %( </script> )
    output.join("").html_safe
  end

  def portal_session_replay_allowed?
    # If the account is enabled with PCI compliance, the sessions should not be recorded.
    current_account.session_replay_enabled? && current_account.account_additional_settings.freshmarketer_linked? && !current_account.secure_fields_enabled?
  end

  def portal_session_replay
    output = current_account.account_additional_settings.freshmarketer_cdn_script
    output.html_safe
  end

  def identify_user
    %(
      <script>
        if(typeof window.FM !== 'undefined') {
          var current_user_email = "#{current_user.try(:email)}";
          window.FM.identify(current_user_email);
          console.log('Session identified: ' + current_user_email)
        }
      </script>
    ).html_safe
  end

  def portal_javascript_object
    { :language => @portal['language'],
      :name => h(@portal['name']),
      :contact_info => h(@portal['contact_info']),
      :current_page_name => @current_page_token,
      :current_tab => @current_tab,
      vault_service: {
        url: PciConstants::DATA_URL,
        max_try: PciConstants::MAX_TRY,
        product_name: PciConstants::ISSUER
      },
      current_account_id: Account.current.id,
      :preferences => preview? ? escaped_portal_preferences : portal_preferences,
      :image_placeholders => { :spacer => spacer_image_url,
                              :profile_thumb => image_path("misc/profile_blank_thumb.jpg"),
                               :profile_medium => image_path("misc/profile_blank_medium.jpg") },
      :falcon_portal_theme => Account.current.falcon_support_portal_theme_enabled?
    }.merge(controller_js_object || {}).to_json
  end

  def controller_js_object
    @current_object if @current_object
  end

  def portal_copyright portal
    %(  <div class="copyright">
        <a href=#{ I18n.t('footer.helpdesk_software_link') } target="_blank"> #{ I18n.t('footer.helpdesk_software') } </a>
        #{ I18n.t('footer.by_freshdesk') }
      </div> ) if Account.current.copy_right_enabled?
  end

  def link_to_cookie_law portal
    %(  <a href="#portal-cookie-info" rel="freshdialog" data-lazy-load="true" class="cookie-link"
        data-width="450px" title="#{ I18n.t('portal.cookie.why_we_love_cookies') }" data-template-footer="">
        #{ I18n.t('portal.cookie.cookie_policy') }
      </a> #{ cookie_law } ).html_safe if Account.current.copy_right_enabled?
  end

  def link_to_privacy_policy portal
    %(  <a href="http://freshdesk.com/privacy" target="_blank" class="privacy-link">
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
      can_delete = false if ticket.is_a?(Helpdesk::ArchiveTicketDrop)

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

  def custom_survey_data comment
    output = []
    if comment.survey.present? and Account.current.new_survey_enabled?
      survey = comment.survey.to_liquid
      output << %(<div class='survey_questions_wrap'>)
        output << custom_survey_default_question(survey)
      output << custom_survey_additional_questions(survey.additional_questions)
        output << %(</div>)
      if comment.description_text.present?
            output << %(<div class="title muted"><b>#{ I18n.t('portal.tickets.comments') }</b></div>)
          end
    end
    output.join('').html_safe
  end

  def custom_survey_default_question(survey)
    output = %( <div class="default_question">
                <div class='ques-desc'>
                    #{survey.default_question}
                </div>
                <div class='ques-ans'>
                    <span class="ticket-rating-label">#{ survey.default_rating_text}</span>
                    <span class = "survey-rating #{ survey.default_rating_class }"></span>
                </div>
              </div>)
  end

  def custom_survey_additional_questions(additional_questions_data)
    output = []
    if additional_questions_data.present?
        output << %(<ul class="survey-additional-questions">)
      for question_obj in additional_questions_data
          output << %(<li>
                      <div class='ques-desc'> #{question_obj['question']} </div>
                      <div class='ques-ans'>

                        <span class='ticket-rating-label'>#{question_obj['rating_text']}</span>
                          <span class="survey-rating #{ question_obj['rating_class'] }"
                            data-class="#{ question_obj['rating_class'] }"></span>
                      </div>
                    </li>)
      end
      output << %(</ul>)
    end
    output.join('').html_safe
  end

  def comment_attachments comment
    output = []

    if(comment.attachments.size > 0 or comment.cloud_files.size > 0)
      output << %(<div class="cs-g-c attachments" id="comment-#{ comment.id }-attachments">)

      can_delete = (comment.user and comment.user.id == User.current.id)
      can_delete = false if comment.is_a?(Helpdesk::ArchiveNoteDrop)

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
    tooltip = "data-toggle='tooltip' title='#{attachment.filename}'" if attachment.filename.size > 15
    output << %(<div class="attachment">)
    output << %(<a href="#{attachment.delete_url}" data-method="delete" data-confirm="#{I18n.t('attachment_delete')}" class="delete mr5"></a>) if can_delete

    output << default_attachment_type(attachment)

    output << %(<div class="attach_content">)
    output << %(<div class="ellipsis">)
    output << %(<a href="#{attachment.url}" class="filename" target="_blank" #{tooltip}
                >#{ attachment.filename.truncate(15) } </a>)
    output << %(</div>)
    output << %(<div>(#{  attachment.size  }) </div>)
    output << %(</div>)
    output << %(</div>)

    output.join('').html_safe
  end

  def cloud_file_item cloud_file, can_delete = false
    output = []

    output << %(<div class="attachment">)
    tooltip = "data-toggle='tooltip' title='#{h(cloud_file.filename)}'" if cloud_file.filename.size > 15
    output << %(<a href="#{cloud_file.delete_url}" data-method="delete" data-confirm="#{I18n.t('attachment_delete')}" class="delete mr5"></a>) if can_delete

    output << %(<img src="/assets/#{cloud_file.provider}_big.png"></span>)

    output << %(<div class="attach_content">)
    output << %(<div class="ellipsis">)
    output << %(<a href="#{cloud_file.url}" class="filename" target="_blank"
              #{tooltip}>#{h(cloud_file.filename.truncate(15))} </a>)
    output << %(<span class="file-size cloud-file"></span>)
    output << %(</div>)
    output << %(</div>)
    output << %(</div>)

    output.join('').html_safe
  end

  def default_attachment_type (attachment)
    output = []

    if attachment.is_image? && attachment.source.has_thumbnail?
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
      "<img src='#{hit_support_discussions_topic_path(@topic)}' alt=' ' aria-hidden='true'/>".html_safe
    when "article_view"
      "<img src='#{hit_support_solutions_article_path(@article)}' alt=' ' aria-hidden='true'/>".html_safe
    else
      ""
    end
  end

  def spacer_image_url
    "#{asset_host_url}/assets/misc/spacer.gif"
  end

  def helpdesk_ticket? ticket
    ticket and ticket.is_a?(Helpdesk::Ticket)
  end

  def archived_ticket? ticket
    ticket and ticket.is_a?(Helpdesk::ArchiveTicket)
  end

  def language_list portal
    return "" if portal.language_list.blank?
    output = ""
    output << %(<div class="banner-language-selector pull-right" data-tabs="tabs"
                data-toggle='tooltip' data-placement="bottom" title="#{Language.current.name if Language.current.name.length > 10}">)
    output << %(<ul class="language-options" role="tablist">)
    output << %(<li class="dropdown">)
    output << %(<h5 class="dropdown-toggle" data-toggle="dropdown">)
    output << %(<span>#{Language.current.name.truncate(10)}</span>)
    output << %(<span class="caret"></span></h5>)
    output << dropdown_menu(portal.language_list)
    output << %(</li></ul></div>)
    output.html_safe
  end

  private

    def portal_preferences
      preferences = current_portal.template.preferences
      if on_mint_preview
         preferences = current_portal.template.get_draft.preferences if current_portal.template.get_draft
      elsif preview? && current_portal.template.get_draft
         preferences = current_portal.template.get_draft.preferences
      end
      preferences || []
    end

    def escaped_portal_preferences
      preferences = portal_preferences
      PORTAL_PREFERENCES_ESCAPE_ATTRIBUTES.each { |attribute| preferences[attribute] = h(preferences[attribute]) }
      preferences
    end

    def preview?
      @preview ||= if User.current
                     is_preview = IS_PREVIEW % { :account_id => current_account.id, :user_id => User.current.id, :portal_id => @portal.id}
                     (!(get_portal_redis_key(is_preview).blank?  && on_mint_preview.blank?)) && !current_user.blank? && current_user.agent?
                   end
    end

    def link_args_to_options(args)
        link_opts = {}
        [:label, :title, :id, :class, :rel].zip(args) {|key, value| link_opts[key] = h(value) unless value.blank?}
        link_opts
      end

    def fetch_custom_field(ticket, field_name)
      ticket.class.eql?(Helpdesk::ArchiveTicket) ? ticket.custom_field_value(field_name) :
        ticket.get_ff_value(field_name)
    end

    def hidden_lang_alert_for_agent
      output = []
      if Account.current.agent_only_language?(Language.current)
        output << %( <div class="alert-assume-agent alert-solid"><span class="ficon-unverified"></span> )
        output << %( #{t('header.agent_only_language',:language => Language.current.name)} )
        output << ' - ' + link_to(t('enable').upcase, hidden_lang_alert_redirection_url, class: 'link') if current_user && current_user.privilege?(:admin_tasks)
        output << %( </div> )
      end
      output.join("").html_safe
    end

    def hidden_lang_alert_redirection_url
      '/a/admin/account/languages'
    end
end
