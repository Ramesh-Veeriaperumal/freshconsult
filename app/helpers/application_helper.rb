# encoding: utf-8
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include ForumHelperMethods
  include AccountConstants
  include Juixe::Acts::Voteable
  include ActionView::Helpers::TextHelper
  include Gamification::GamificationUtil
  include ChatHelper
  include Concerns::ApplicationViewConcern
  include BotHelper
  include AttachmentHelper
  include ConfirmDeleteHelper
  include RtlHelper
  include MemcacheKeys
  include Integrations::Util
  include Integrations::IntegrationHelper
  include CommunityHelper
  include TabHelper
  include ReportsHelper
  include DateHelper
  include StoreHelper
  include Redis::IntegrationsRedis
  include JsonEscape
  include Concerns::AppConfigurationConcern
  include FalconHelperMethods
  include YearInReviewMethods
  include Redis::OthersRedis
  include Redis::RedisKeys
  include SandboxConstants
  include Social::Util

  require "twitter"

  # Methods: get_app_config, is_application_installed?, get_app_details, installed_apps - moved to Concerns::AppConfigurationConcern
  # Methods: formated_date - moved to Concerns::ApplicationViewConcern

  ASSETIMAGE = { :help => "/assets/helpimages" }
  ASSET_MANIFEST = {}
  USER_NOTIFICATION_PREFS = [
    { :text => "customer_responded", :default => true },
    { :text => "ticket_status_updated", :default => true },
    { :text => "ticket_assigned", :default => true },
    { :text => "private_note_created", :default => true },
    { :text => "public_note_created", :default => true },
    { :text => "ticket_assigned_to_group", :default => false },
    { :text => "ticket_created", :default => false }
  ].freeze

  #Add the features you want to send to inline manual(for segmenting) to the below array in string format
  #NOTE: The limit for the features is 17 items with up to 24 characters each. 
  # i.e, we can only send first 24 characters of first 17 enabled features for an account. 
  INLINE_MANUAL_FEATURES = [:mint_portal_applicable]

  INLINE_MANUAL_FEATURE_THRESHOLDS = { char_length: 24, max_count: 17}

  SANDBOX_URL_PATHS = [
      '/admin/va_rules',
      '/admin/supervisor_rules',
      '/admin/observer_rules',
      '/helpdesk/scenario_automations',
      '/admin/email_notifications',
      '/admin/business_calendars',
      '/helpdesk/tags',
      '/helpdesk/ticket_templates',
      '/ticket_fields',
      '/admin/contact_fields',
      '/admin/company_fields',
      '/agents',
      '/groups',
      '/admin/roles',
      '/helpdesk/canned_responses/folders',
      '/helpdesk/sla_policies',
      '/admin/custom_surveys',
      '/admin/products',
      '/admin/security'
    ]

  SANDBOX_NOTIFICATION_STATUS = [6, 8, 9, 10, 98].freeze

  def open_html_tag
    html_conditions = [ ["lt IE 7", "ie6"],
                        ["IE 7", "ie7"],
                        ["IE 8", "ie8"],
                        ["IE 9", "ie9"],
                        ["IE 10", "ie10"],
                        ["(gt IE 10)|!(IE)", "", true]]
    language = I18n.locale.to_s
    language = language.force_encoding('utf-8') if language.respond_to?(:force_encoding)
    date_format = (DATEFORMATS[current_account.account_additional_settings.date_format] if current_account.account_additional_settings) || :non_us
    html_conditions.map { |h|
      %(
        <!--[if #{h[0]}]>#{h[2] ? '<!-->' : ''}<html class="no-js #{h[1]}" lang="#{
          language }" dir="#{current_direction?}" data-date-format="#{date_format}">#{h[2] ? '<!--' : ''}<![endif]-->)
    }.to_s.html_safe
  end

  def spacer_image_url
    "#{asset_host_url}/assets/misc/spacer.gif"
  end

  def redirect_falcon_path
    FalconRedirection.falcon_redirection_path request.path_info, request.query_string
  end

  def trial_expiry_title(trial_days)
    if trial_days == 0
      t('trial_one_more_day').html_safe
    elsif trial_days > 0
      t('trial_will_expire_in', :no_of_days => pluralize(trial_days, t('trial_day'), t('days')) ).html_safe
    else trial_days < 0
      t('trial_expired_on' ).html_safe
    end
  end

  def format_float_value(val)
    if !(val.is_a? Fixnum)
      sprintf( "%0.01f", val)
    else
      return val.to_s
    end
  end

  def helpdesk_theme_url
    "/helpdesk/theme.css?v=#{current_portal.updated_at.to_i}"
  end

  def support_theme_url
    stylesheet_name = is_current_language_rtl? ? "theme_rtl.css" : "theme.css"
    if preview? || (mint_preview_key && get_others_redis_key(mint_preview_key))
      query_string ="#{Time.now.to_i}&preview=true"
    else
      query_string = "#{current_portal.template.updated_at.to_i}"
    end
    "/support/#{stylesheet_name}?v=#{query_string}"
  end

  def facebook_theme_url
    stylesheet_name = is_current_language_rtl? ? "theme_rtl.css" : "theme.css"
    if preview? || (mint_preview_key && get_others_redis_key(mint_preview_key))
      query_string ="#{Time.now.to_i}&preview=true"
    else
      query_string = "#{current_portal.template.updated_at.to_i}"
    end
    "/facebook/#{stylesheet_name}?v=#{query_string}"
  end


  def logo_url(portal = current_portal)
    MemcacheKeys.fetch(["v8","portal","logo",portal],7.days.to_i) do
        portal.logo.nil? ? "/assets/misc/logo.png?702017" :
        AwsWrapper::S3.presigned_url(portal.logo.content.bucket_name, portal.logo.content.path(:logo), expires_in: 7.days.to_i, secure: true)
    end
  end

  def fav_icon_url(portal = current_portal)
    portal.fetch_fav_icon_url
  end

  def ticket_status_hash
    Hash[Helpdesk::TicketStatus.status_names(current_account)]
  end

  def timediff_in_words(interval)
    secs  = interval.to_i
    mins  = (secs / 60).to_i
    secs = secs - (mins * 60)

    hours = (mins / 60).to_i
    mins = mins - (hours * 60)

    days  = (hours / 24).to_i
    hours = hours - (days * 24)

    if (interval.to_i <= 0)
      I18n.t('since_a_second')
    elsif days > 0
      I18n.t('no_of_days', :days => "#{days}" , :hours => "#{hours % 24}" )
    elsif hours > 0
      I18n.t('no_of_hours', :hours => "#{hours}", :minutes => "#{mins % 60}" )
    elsif mins > 0
      I18n.t('no_of_minutes', :minutes => "#{mins}", :seconds => "#{secs % 60}" )
    elsif secs >= 0
      I18n.t('no_of_seconds', :seconds => "#{secs}")
    end

  end

  def percentage(numerator, denominator)
    if denominator == 0
      "-"
    else
      format_float_value(100 * numerator / denominator) + '%'
    end
  end

  def show_flash
    @show_flash = [:notice, :warning, :error].collect {|type| content_tag('div', flash[type], :id => type, :class => "alert #{type}") if flash[type] }.to_s.html_safe
  end

  def ember_admin_flash
    admin_flash = []

    [[:notice, "success"], [:warning, "warning"], [:error, "danger"]].each {|flash_obj|
      type = flash_obj[0]
      admin_flash << { "type" => flash_obj[1], "message" => flash[type]} if flash[type]
    }

    admin_flash
  end

  def show_admin_flash
    [:notice, :warning, :error].collect {|type| content_tag('div', ("<a class='close' data-dismiss='alert'>×</a>" + flash[type]).html_safe, :id => type, :class => "alert alert-block alert-#{type}") if flash[type] }.to_s.html_safe
  end

  def show_announcements
    if privilege?(:manage_tickets)
      @current_announcements ||= SubscriptionAnnouncement.current_announcements(session[:announcement_hide_time])
      render :partial => "/shared/announcement", :object => @current_announcements unless @current_announcements.blank?
    end
  end

  def page_title
    portal_name = " : #{h(current_portal.portal_name.html_safe)}" if current_portal.portal_name.present?
    "#{(@page_title || t('helpdesk_title'))}#{portal_name}"
  end

  def page_description
    @page_description
  end

  def page_keywords
    @page_keywords
  end

  def page_canonical
    @page_canonical
  end

  def tab(title, url, cls = false, tab_name="")
    options = current_user && current_user.agent? ? {:"data-pjax" => "#body-container", :"data-keybinding" => shortcut("app_nav.#{strip_tags(title).downcase}")} : {}
    if tab_name.eql?(:tickets)
      options.merge!({:"data-parallel-url" => "/helpdesk/tickets/filter_options", :"data-parallel-placeholder" => "#ticket-leftFilter"})
    end
    if tab_name.eql?(:reports) && ( request.fullpath.include?("reports/custom_survey") || request.fullpath.include?("reports/timesheet") || request.fullpath.include?("phone/summary_reports") || request.fullpath.include?("freshchat/summary_reports"))
       options.delete(:"data-pjax")
    end
    content_tag('li', link_to(strip_tags(title), url, options), :class => ( cls ? "active": "" ), :"data-tab-name" => tab_name )
  end

  def show_ajax_flash(page)
    page.replace_html :noticeajax, ([:notice, :warning, :error].collect {|type| content_tag('div', flash[type])})
    page << "$('noticeajax').show()"
    page << "closeableFlash('#noticeajax')"
    flash.discard
  end

  def show_growl_flash(page)
    [:notice, :warning, :error].each do |type|
      if flash[type].present?
        page << "jQuery.gritter.add({ text: '#{flash[type]}'
              , fade: true, speed: 'fast', position: 'top-right', class_name: 'flash-#{type}' });"
      end
    end
    flash.discard
  end


  def pjax_link_to(title, url, options = {})
    options.merge!({:"data-pjax" => "#body-container"})
    link_to(title, url, options)
  end

  def each_or_message(partial, collection, message, locals = {})
    render(:partial => partial, :collection => collection, :locals => locals) || content_tag(:div, message.html_safe, :class => "list-noinfo")
  end

  def each_or_new(partial_item, collection, partial_form, partial_form_locals = {})
    render(:partial => partial_item, :collection => collection) || render(:partial => partial_form, :locals => partial_form_locals)
  end

  # A helper to show an enable disalbed toggle button like iphone
  # The toggle_url can be a controller action that will toggle based on the status
  def on_off_button(obj, toggle_url, text_on = t("enabled"), text_off = t("disabled"), tip_on = t("tip_on"), tip_off = t("tip_off"))
    button_text = (obj) ? text_on : text_off
    button_title = (obj) ? tip_off : tip_on
    button_class = (obj) ? "iphone-active" : "iphone-inactive"
    link_to "<strong> #{ button_text } </strong><span></span>".html_safe, toggle_url, { :class =>
      "uiButton special #{button_class} custom-tip-top", :title => button_title, :method => 'put' }
  end

  def get_img(file_name, type)
    image_tag("#{ASSETIMAGE[type]}/#{file_name}", :class => "#{type}_image")
  end

  def render_item(value, type = "text")
    unless value.blank?
      case type
        when "text" then
          content_tag :div, value
        when "facebook" then
          auto_link("http://facebook.com/#{value}").html_safe
        when "twitter" then
          value = value.gsub('@','')
          link_to("@#{value}" , "http://twitter.com/#{value}")
        when "link" then
          auto_link(value).html_safe
      end
    end
  end

  def fd_menu_link(text, url, is_active)
    text << "<span class='icon ticksymbol'></span>" if is_active
    class_name = is_active ? "active" : ""
    link_to(text, url, :class => class_name, :tabindex => "-1")
  end

  def btn_dropdown_menu(btn, list, options = {})
    output = ""
    output << %(<div class="btn-group dropdown">)
    output << link_to(btn[0], btn[1], options.merge({:class => "btn btn-primary", "tabindex" => "-1"}))
		output << %(<button class="btn btn-primary dropdown-toggle" data-toggle="dropdown" href="#">
			            <i class="caret"></i>
		            </button>)
    output << dropdown_menu(list, options)
    output << %(</div>)

    output.html_safe
  end

  def dropdown_menu(list, options = {})
    return if list.blank?
    output = ""
    output << %(<ul class="dropdown-menu #{options['ul_class']}" role="menu" aria-labelledby="dropdownMenu">)

    list.each do |item|
      unless item.blank?
        if item[0] == :divider
          output << %(<li class="divider"></li>)
        else
          li_opts = (item[3].present?) ? options.merge(item[3]) : options
          option_link = link_to(item[0], item[1], li_opts, "tabindex" => "-1")
          output << ( item[2] ? %(<li class="selected" ><span class='icon ticksymbol'></span>#{option_link}</li>) : %(<li>#{option_link}</li>) )
        end
      end
    end
    output << %(</ul>)
    output.html_safe
  end

  def render_placeholders(placeholders_list)
    category_titles=""
    category_placeholders=""
    placeholders_list.each do |category, placeholders|
      if placeholders.length > 0
        category_titles << content_tag(:li,
                              content_tag(:a,
                                t("admin.placeholders.#{category}"),
                                :class => "placeholder-category-title",
                                :"data-toggle" => "tab",
                                :"href" => "##{category}-list"
                                 ).html_safe,
                              :class => '',
                              :"data-category" => category).html_safe
        category_placeholders  <<  content_tag(:div,
                              placeholder_list(placeholders) ,
                              :id => "#{category}-list",
                              :class => "tab-pane fade placeholder-category-list #{category}-list",
                              :"data-category"=>category).html_safe
      end
    end

    content_tag(:ul, category_titles.html_safe, :class => 'nav nav-tabs vertical placeholder-category-title-container').html_safe + content_tag(:div, category_placeholders.html_safe, :class => ' tab-content placeholder-category-list-container', :"rel" => "mouse-wheel", :"data-scroll-speed" => "10").html_safe
  end

  def placeholder_list(fields)
    ph_button_list = ""
    fields.each do |field|
    	ph_button_list << content_tag(:li,
													content_tag(:div,
														(content_tag(:button,
															field[1],
															:class => 'btn btn-flat tooltip',
															:"data-placeholder" => field[0],
															:title => field[2]) + nested_ph_menu(field[4])).html_safe,
													:class => 'btn-group').html_safe,
                        :class => 'ph-item', :id => "placeholder-btn-#{field[3]}")
    end
    content_tag(:ul, ph_button_list.html_safe, :class => 'ph-list').html_safe
  end

  def nested_ph_menu nested_data
    return "" unless nested_data.try(:[], :nested).present?

    nested_menu = ""
    nested_data[:nested].each do |nested|
	    nested_menu << content_tag(:li,
                        link_to(nested[1], '#', :class => 'ph-btn tooltip', :"data-placeholder" => nested[0]),
                        :id => "placeholder-btn-#{nested[3]}")
    end
    (link_to(content_tag(:span, "", :class => 'caret'), '#', :class => 'btn btn-flat dropdown-toggle', :"data-toggle" => 'dropdown') +
    content_tag(:ul, nested_menu.html_safe, :class => 'dropdown-menu btn-block')).html_safe
  end

  def forum_options
    _forum_options = []
    current_account.forum_categories.each do |c|
      _forums = c.forums.map{ |f| [f.name, f.id] }
      _forum_options << [ c.name, _forums ] if _forums.present?
    end
    _forum_options
  end

  def navigation_tabs
    tabs = [
      ['/home',               :home,          !privilege?(:manage_tickets) ],
      ['/helpdesk/dashboard',  :dashboard,    privilege?(:manage_tickets)],
      ['/helpdesk/tickets',    :tickets,      privilege?(:manage_tickets)],
      social_tab,
      ['/solution/categories', :solutions,    privilege?(:view_solutions)],
      ['/discussions',        :forums,        forums_visibility?],
      ['/contacts',           :customers,     privilege?(:view_contacts)],
      ['/support/tickets',     :checkstatus,  !privilege?(:manage_tickets)],
      ['/reports',            :reports,       privilege?(:view_reports) ],
      ['/admin/home',         :admin,         privilege?(:view_admin)],
    ]

#    history_active = false;
#
#    history = (session[:helpdesk_history] || []).reverse.map do |h|
#      active = h[:url][:id] == @item.to_param &&
#               h[:url][:controller] == params[:controller]
#
#      history_active ||= active
#
#      tab(h[:title], h[:url], "#{active ? :active : :history} #{ h[:class] || '' }")
#    end

    navigation = tabs.map do |s|
      next unless s[2]
      active = (params[:controller] == s[0]) || (s[1] == @selected_tab || "/#{params[:controller]}" == s[0]) #selected_tab hack by Shan  !history_active &&
      tab(
        s[3] || t("header.tabs.#{s[1].to_s}") ,
        s[0] ,
        active && :active,
        s[1]
      ).html_safe
    end
    navigation.to_s.html_safe
  end

  def subscription_tabs
    tabs = [
      [customers_admin_subscriptions_path, :customers, "Customers" ],
      [admin_affiliates_path, :affiliates, "Affiliates" ],
      [admin_subscription_payments_path, :payments, "Payments" ],
      [admin_subscription_announcements_path, :announcements, "Announcements" ]
    ]

    navigation = tabs.map do |s|
      content_tag(:li, link_to(s[2], s[0]), :class => ((@selected_tab == s[1]) ? "active" : ""))
    end
  end

  def html_list(type, elements, options = {}, activeitem = 0)
    if elements.empty?
      ""
    else
      lis = elements.map { |x| content_tag("li", x.to_s.html_safe, :class => ("active first" if (elements[activeitem] == x)))  }.to_s.html_safe
      content_tag(type, lis, options)
    end
  end

  def ul(*args)
    html_list("ul", *args)
  end

  def ol(*args)
    html_list("ol", *args)
  end

  def check_box_link(text, checked, check_url, check_method, uncheck_url, uncheck_method = :post)
    form_tag("", :method => :put) +
    check_box_tag("", 1, checked, :onclick => %{this.form.action = this.checked ? '#{check_url}' : '#{uncheck_url}';
      Element.down(this.form, "input[name=_method]").value = this.checked ? '#{check_method}' : '#{uncheck_method}';
      this.form.submit();    }) +
    content_tag("label", text, :class=>"reminder #{ checked ? "checked" : "unchecked" }")

  end

  def email_quoted?(text)
    text =~ /[^\n\r]+:\s*>/m
  end

  def email_before_quoted(text)
    text.split(/[^\n\r]+:\s*>/m)[0]
  end

  def email_after_quoted(text)
    before = email_before_quoted(text)
    text[before.size, text.size - before.size]
  end

  #Copied from SAAS kit
  def flash_notices
    [:notice, :error].collect {|type| content_tag('div', flash[type], :id => type) if flash[type] }
  end

  # Render a submit button and cancel link
  def submit_or_cancel(cancel_url = session[:return_to] ? session[:return_to] : url_for(:action => 'index'), label = 'Save Changes')
    content_tag(:div, submit_tag(label) + ' or ' +
      link_to('Cancel', cancel_url), :id => 'submit_or_cancel', :class => 'submit')
  end

  def discount_label(discount)
    (discount.percent? ? number_to_percentage(discount.amount * 100, :precision => 0) : number_to_currency(discount.amount)) + ' off'
  end
  #Copy ends here

  #Liquid template parsing methods used in Dashboard and Tickets view page
  def eval_activity_data(data)
    if data['eval_args'].nil?
      data.each_pair do |k,v|
        data[k] = h v
      end
    else
      data['eval_args'].each_pair do |k, v|
        data[k] = safe_send(v[0].to_sym, v[1])
      end
    end

    data
  end

  def language_name id
    # This method might seem unnecessary, but this is being used while displaying activities,
    # Where eval_args will have a key :language_name
    Language.find(id).name
  end

  def formatted_dueby_for_activity(time_in_seconds)
    "#{formated_date(Time.zone.at(time_in_seconds))}".tap do |f_t| f_t.gsub!(' at', ',') end
  end

  def target_topic_path(topic_id)
    topic = current_account.topics.find(topic_id)
    link_to topic.title, discussions_topic_path(topic.id)
  end

  def responder_path(args_hash)
    request.format == "application/json" ? args_hash['name'] : link_to(h(args_hash['name']), user_path(args_hash['id']))
  end

  def comment_path(args_hash, link_display = t('activities.note'), options={ :'data-pjax' => false })
    link_to(link_display, "#{helpdesk_ticket_path args_hash['ticket_id']}#note#{args_hash['comment_id']}", options)
  end

  def email_response_path(args_hash)
    comment_path(args_hash, t('activities.email_response'))
  end

  def reply_path(args_hash)
    comment_path(args_hash, t('activities.reply'))
  end

  def ecommerce_path(args_hash)
    comment_path(args_hash, t('activities.ecommerce'))
  end

  def fwd_path(args_hash)
    comment_path(args_hash, t('activities.forwarded'))
  end

  def twitter_path(args_hash)
    comment_path(args_hash, t('activities.tweet'))
  end

  def merge_ticket_path(args_hash)
    request.format == "application/json" ? args_hash['subject']+"(##{args_hash['ticket_id']})" :
                                          link_to(args_hash['subject']+"(##{args_hash['ticket_id']})", "#{helpdesk_ticket_path args_hash['ticket_id']}}")
  end

  def split_ticket_path(args_hash)
    request.format == "application/json" ? args_hash['subject']+"(##{args_hash['ticket_id']})" :
                                           link_to(args_hash['subject']+"(##{args_hash['ticket_id']})", "#{helpdesk_ticket_path args_hash['ticket_id']}}")
  end

   def timesheet_path(args_hash, link_display = t('activities.time_entry'))
    link_display
  end
  #Liquid ends here..

  #Ticket place-holders, which will be used in email and comment contents.t('placeholder.ticket_id')
  def ticket_placeholders #To do.. i18n
    place_holders = {
      :tickets => [
                      ['{{ticket.id}}',               t('placeholder.ticket_id') ,       '',        'ticket_id'],
                      ['{{ticket.subject}}',          t('placeholder.ticket_subject'),          '',        'ticket_subject'],
                      ['{{ticket.description}}',      t('placeholder.ticket_description'),        '',         'ticket_description'],
                      ['{{ticket.url}}',              t('placeholder.ticket_url') ,            t('placeholder.tooltip.ticket_url'),         'ticket_url'],
                      ['{{ticket.portal_url}}',       t('placeholder.ticket_portal_url'),     t('placeholder.tooltip.ticket_portal_url'),          'ticket_portal_url'],
                      ['{{ticket.tags}}',             t('placeholder.ticket_tags'),           '',         'ticket_tags'],
                      ['{{ticket.latest_public_comment}}',  t('placeholder.ticket_latest_public_comment'),  '',         'ticket_latest_public_comment'],
                      ['{{ticket.latest_private_comment}}', t('placeholder.ticket_latest_private_comment'), '', 'ticket_latest_private_comment'],
                      ['{{ticket.group.name}}',       t('placeholder.ticket_group_name'),       '',          'ticket_group_name'],
                      ['{{ticket.agent.name}}',       t('placeholder.ticket_agent_name'),       '',        'ticket_agent_name'],
                      ['{{ticket.agent.email}}',      t('placeholder.ticket_agent_email'),        "",         'ticket_agent_email']
                    ],
      :ticket_fields => [
                      ['{{ticket.status}}',         t('placeholder.ticket_status') ,          '',         'ticket_status'],
                      ['{{ticket.priority}}',         t('placeholder.ticket_priority'),         '',        'ticket_priority'],
                      ['{{ticket.source}}',         t('placeholder.ticket_source'),           t('placeholder.tooltip.ticket_source'),        'ticket_source'],
                      ['{{ticket.ticket_type}}',      t('placeholder.ticket_type'),        '',         'ticket_type']
                    ],
      :requester => [
                      ['{{ticket.requester.name}}',     t('placeholder.ticket_requester_name'),       '',         'ticket_requester_name'],
                      ['{{ticket.requester.firstname}}' , t('placeholder.ticket_requester_firstname'), '',          'ticket_requester_firstname'],
                      ['{{ticket.requester.lastname}}' , t('placeholder.ticket_requester_lastname'), '',           'ticket_requester_lastname'],
                      ['{{ticket.from_email}}',    t('placeholder.ticket_requester_email'),      "",         'ticket_requester_email'],
                      ['{{ticket.requester.phone}}', t('placeholder.ticket_requester_phone'),   "",       'ticket_requester_phone'],
                      # ['{{ticket.requester.email}}', t('placeholder.contact_primary_email'), "", 'contact_primary_email'],
                      ['{{ticket.requester.address}}', t('placeholder.ticket_requester_address'),   "",       'ticket_requester_address']
                    ],
      :company => [
                      ['{{ticket.company.name}}',     t('placeholder.ticket_company_name'),       '',         'ticket_company_name'],
                      ['{{ticket.company.description}}',     t('placeholder.ticket_company_description'),       '',         'ticket_company_description'],
                      ['{{ticket.company.note}}',     t('placeholder.ticket_company_note'),       '',         'ticket_company_note'],
                      ['{{ticket.company.domains}}',     t('placeholder.ticket_company_domains'),       '',         'ticket_company_domains']
                    ],
      :helpdesk => [
                      ['{{helpdesk_name}}', t('placeholder.helpdesk_name'), '',         'helpdesk_name'],
                      ['{{ticket.portal_name}}', t('placeholder.ticket_portal_name'), t('placeholder.tooltip.ticket_portal_name'),        'ticket_portal_name'],
                      ['{{ticket.product_description}}', t('placeholder.ticket_product_description'), t('placeholder.tooltip.ticket_product_description'),         'ticket_product_description']
                    ]
    }

    #Shared ownership placeholders
    if current_account.shared_ownership_enabled?
      place_holders[:tickets] +=
        [['{{ticket.internal_group.name}}',      t('placeholder.ticket_internal_group_name'),       "",         'ticket_internal_group_name'],
        ['{{ticket.internal_agent.name}}',       t('placeholder.ticket_internal_agent_name'),       "",         'ticket_internal_agent_name'],
        ['{{ticket.internal_agent.email}}',      t('placeholder.ticket_internal_agent_email'),      "",         'ticket_internal_agent_email']]
    end

    if current_account.unique_contact_identifier_enabled?
      place_holders[:requester] += [['{{ticket.requester.unique_external_id}}',   t('placeholder.unique_external_id'), '',       'unique_external_id']]
    end

    # Custom Field Placeholders
    current_account.ticket_fields.non_encrypted_custom_fields.each { |custom_field|
      nested_vals = []
      custom_field.nested_ticket_fields.each { |nested_field|
        name = nested_field.name[0..nested_field.name.rindex('_')-1]
        nested_vals << ["{{ticket.#{name}}}", nested_field.label, "", "ticket_#{name}"]
      }

      name = custom_field.name[0..custom_field.name.rindex('_')-1]
      place_holders[:ticket_fields] << ["{{ticket.#{name}}}", custom_field.label, "", "ticket_#{name}", { :nested => nested_vals }]
    }

    # Contact Custom Field Placeholders
    current_account.contact_form.custom_contact_fields(true).each { |custom_field|
      name = custom_field.name[3..-1]
      #date fields disabled till db fix
      place_holders[:requester] <<  ["{{ticket.requester.#{name}}}", "Requester #{custom_field.label}", "", "ticket_requester_#{name}"]
    }

    # TAM company fields place holders
    if current_account.tam_default_fields_enabled?
      current_account.company_form.tam_default_fields.each { |field|
        place_holders[:company] <<  ["{{ticket.company.#{field.name}}}",
                                     "Company #{field.label}", "", 
                                     "ticket_requester_company_#{field.name}"]
      }
    end

    # Company Custom Field Placeholders
    current_account.company_form.custom_company_fields(true).each { |custom_field|
      name = custom_field.name[3..-1]
      #date fields disabled till db fix
      place_holders[:company] <<  ["{{ticket.company.#{name}}}", "Company #{custom_field.label}", "", "ticket_requester_company_#{name}"]
    }

    # Survey Placeholders
    place_holders[:tickets] << ['{{ticket.satisfaction_survey}}', t('placeholder.ticket_satisfaction_survey'),
                      t('placeholder.tooltip.satisfaction_survey'), 'ticket_satisfaction_survey'
                      ] if current_account.any_survey_feature_enabled_and_active? && params[:type] != 'reply_template'
    place_holders[:tickets] << ['{{ticket.surveymonkey_survey}}', t('placeholder.ticket_suverymonkey_survey'),
                      t('placeholder.tooltip.ticket_suverymonkey_survey'), 'ticket_suverymonkey_survey'
                      ] if Integrations::SurveyMonkey.placeholder_allowed?


    # Ticket Public URL placeholder
    place_holders[:tickets] << ['{{ticket.public_url}}', 'Public Ticket URL' ,
                      'URL for accessing the tickets without login', 'ticket_public_url'
                      ] if current_account.features?(:public_ticket_url) && !current_account.hipaa_and_encrypted_fields_enabled?

    place_holders[:tickets] << ['{{ticket.due_by_time}}', t('placeholder.ticket_due_by_time'), '',
                                'ticket_due_by_time'] if current_account.sla_management_v2_enabled?

    place_holders
  end


  def group_avatar
    content_tag( :div, image_tag("/assets/fillers/group-icon.png",{:onerror => "imgerror(this)",:size_type => :thumb} ), :class => "image-lazy-load", :size_type => :thumb )
  end
  # Avatar helper for user profile image
  # :medium and :small size of the original image will be saved as an attachment to the user
  def user_avatar(user, profile_size = :thumb, profile_class = "preview_pic", options = {})
    #Hack. prod issue. ticket: 55851. Until we find root cause. It was not rendering view at all.
    #Remove once found the cause.
    user = User.new if user.nil?
    if user.avatar
      img_url = avatar_cached_url(user, profile_size)
      img_tag_options = {
          :onerror => "imgerror(this)",
          :alt => user.name,
          :size_type => profile_size,
          :data => {
            :src => img_url,
            :"src-retina" => img_url
            },
          :class => profile_size
        }
      avatar_image_generator(img_tag_options, profile_size, profile_class)
    elsif is_user_social(user, profile_size).present?
        img_tag_options = {
          :onerror => "imgerror(this)",
          :alt => user.name,
          :size_type => profile_size,
          :data => {
            :src => is_user_social(user, profile_size),
            :"src-retina" => is_user_social(user, profile_size)
            },
          :class => profile_size
        }
      avatar_image_generator(img_tag_options, profile_size, profile_class)
    else
      name = Account.current.freshid_integration_enabled? && user.name.nil? ? "" : user.name
      avatar_generator(name, profile_size, profile_class, options)
    end
  end

  def avatar_image_generator(img_tag_options, profile_size, profile_class)
      ActionController::Base.helpers.content_tag(:div,
          ActionController::Base.helpers.image_tag("/assets/misc/profile_blank_#{profile_size}.jpg", img_tag_options),
          :class => "#{profile_class} image-lazy-load", :size_type => profile_size )
  end

  def avatar_cached_url(user, profile_size)
    MemcacheKeys.fetch(["v16","avatar",profile_size ,user],7.days.to_i) do
      user.avatar ? user.avatar.expiring_url(profile_size,7.days.to_i) : is_user_social(user, profile_size)
    end
  end

  def unknown_user_avatar( profile_size = :thumb, profile_class = "preview_pic", options = {} )
    img_tag_options = { :onerror => "imgerror(this)", :alt => t('user.profile_picture') }
    if options.include?(:width)
      img_tag_options[:width] = options.fetch(:width)
      img_tag_options[:height] = options.fetch(:height)
    end
    content_tag( :div, (image_tag "/assets/misc/profile_blank_#{profile_size}.jpg", img_tag_options ), :class => profile_class, :size_type => profile_size )
  end

  def user_avatar_url(user, profile_size = :thumb)
    (user.avatar ? user.avatar.expiring_url(profile_size, 7.days.to_i) : is_user_social(user, profile_size)) if user.present?
  end

  def user_avatar_with_expiry( user, expiry = 300)
    user_avatar(user,:thumb,"preview_pic",{:expiry => expiry, :width => 36, :height => 36})
  end

  def is_user_social( user, profile_size)
    if user.fb_profile_id
      profile_size = (profile_size == :medium) ? "large" : "square"
      facebook_avatar(user.fb_profile_id, profile_size)
    else
      false
    end
  end

  def avatar_generator( username, profile_size = :thumb, profile_class, opt )
    img_tag_options = { :onerror => "imgerror(this)", :alt => t('user.profile_picture'), :class => [profile_size, profile_class] }
    username = username.lstrip
    if username.present? && isalpha(username[0]).present?
       ActionController::Base.helpers.content_tag( :div, username[0], :class => "#{profile_class} avatar-text text-center #{profile_size} bg-#{unique_code(username)}" )
    else
       ActionController::Base.helpers.content_tag( :div, (ActionController::Base.helpers.image_tag "/assets/misc/profile_blank_#{profile_size}.jpg", img_tag_options ), :class => profile_class, :size_type => profile_size )
    end
  end

  # Avatar helper for user profile image
  # :medium and :small size of the original image will be saved as an attachment to the user
  def senti_user_avatar(user, sentiment, profile_size = :thumb, profile_class = "preview_pic", options = {})
    #Hack. prod issue. ticket: 55851. Until we find root cause. It was not rendering view at all.
    #Remove once found the cause.
    user = User.new if user.nil?
    if user.avatar
      img_url = avatar_cached_url(user, profile_size)
      img_tag_options = {
          :onerror => "imgerror(this)",
          :alt => user.name,
          :size_type => profile_size,
          :data => {
            :src => img_url,
            :"src-retina" => img_url
            },
          :class => profile_size
        }
      senti_avatar_image_generator(img_tag_options, profile_size, profile_class, sentiment, options)
    elsif is_user_social(user, profile_size).present?
        img_tag_options = {
          :onerror => "imgerror(this)",
          :alt => user.name,
          :size_type => profile_size,
          :data => {
            :src => is_user_social(user, profile_size),
            :"src-retina" => is_user_social(user, profile_size)
            },
          :class => profile_size
        }
      senti_avatar_image_generator(img_tag_options, profile_size, profile_class, sentiment, options)
    else
        senti_avatar_generator(user.name, profile_size, profile_class, options, sentiment)
    end
  end

  def senti_avatar_image_generator(img_tag_options, profile_size, profile_class, sentiment, options)

      content_tag(:div, :class => "#{profile_class} image-lazy-load", :size_type => profile_size ) do
        image_tag("/assets/misc/profile_blank_#{profile_size}.jpg", img_tag_options)+
        get_senti_i_tag(sentiment, options)
      end
  end

  def senti_avatar_generator( username, profile_size = :thumb, profile_class, opt, sentiment )

    img_tag_options = { :onerror => "imgerror(this)", :alt => t('user.profile_picture'), :class => [profile_size, profile_class]}
    username = username.lstrip
    if username.present? && isalpha(username[0]).present?
      content_tag( :div, :class => "#{profile_class} avatar-text text-center #{profile_size} bg-#{unique_code(username)}" ) do
        content_tag(:p, username[0])+
        get_senti_i_tag(sentiment, opt)
      end
    else
       content_tag( :div, :class => profile_class, :size_type => profile_size ) do
        (image_tag "/assets/misc/profile_blank_#{profile_size}.jpg", img_tag_options )+
        get_senti_i_tag(sentiment, opt)
      end
    end
  end

  def get_senti_image_tag(sentiment)

    senti_img_tag_options = { :onerror => "imgerror(this)", :alt => t('user.profile_picture'), :class => ['sentiment', sentiment, 'tooltip'], :title => get_senti_title(sentiment)}
    if sentiment
      return image_tag(senti_image_locator(sentiment), senti_img_tag_options)
    else
      return ""
    end

  end

  def get_senti_i_tag(sentiment, opt)
    if sentiment
      if opt.include?(:senti_hover)
        i_tag = content_tag( :i, :rel=> "sentiment-hover", :class => "sentiment #{sentiment} #{senti_class_locator(sentiment)}", :title => "#{get_senti_title(sentiment)}" ) do
        end
      else
        i_tag = content_tag( :i, :class => "sentiment tooltip #{sentiment} #{senti_class_locator(sentiment)}", :title => "#{get_senti_title(sentiment)}" ) do
        end
      end
      return i_tag
    else
      return ""
    end
  end

  #TODO: Convert following functions to Constants
  def get_senti_title(sentiment)

    if sentiment == -2
      return "Angry"
    elsif sentiment == -1
      return "Sad"
    elsif sentiment == 1
      return "Happy"
    elsif sentiment == 2
      return "Very Happy"
    else
      return "Neutral"
    end
  end

  def senti_class_locator(sentiment)

    if sentiment == -2
      return "symbols-emo-angry-20"
    elsif sentiment == -1
      return "symbols-emo-sad-20"
    elsif sentiment == 1
      return "symbols-emo-happy-20"
    elsif sentiment == 2
      return "symbols-emo-veryHappy-20"
    else
      return "symbols-emo-neutral-20"
    end
  end

  def unique_code(username)
    images = Dir.glob(Rails.root+"public/images/avatar/background/1x/*.*")
    hash = 0
    username.each_byte do |c|
      hash = c + ((hash << 5) - hash);
    end
    unique_code = hash % (images.length)
    unique_code
  end

  def isalpha(str)
    str.match(/[^!@#,\$%\^\&\*\(\)\+_\-\?\<\>:"';\.\d ]$/)
  end

  def s3_twitter_avatar(handle, profile_size = "thumb")
    handle_avatar = MemcacheKeys.fetch(["v2","twt_avatar", profile_size, handle], 7.days.to_i) do
      handle.avatar ? handle.avatar.expiring_url(profile_size.to_sym, 7.days.to_i) : "/assets/misc/profile_blank_#{profile_size}.jpg"
    end
    handle_avatar
  end

  def facebook_avatar( facebook_id, profile_size = "square")
    "https://graph.facebook.com/#{facebook_id}/picture?type=#{profile_size}"
  end

  # User details page link should be shown only to agents and admin
  def link_to_user(user, options = {})
    return if user.blank?

    if privilege?(:view_contacts) && !collab_ticket_view?
      default_opts = { :class => "username",
                       :rel => "contact-hover",
                       "data-contact-id" => user.id,
                       "data-contact-url" => hover_card_contact_path(user)  }

      pjax_link_to(options[:avatar] ? user_avatar(user) : h(user), user, default_opts.merge(options))
      # link_to(h(user.display_name), user, options)
    else
      content_tag(:strong, h(user.display_name), options)
    end
  end

  def link_to_system_rule(rule)
    rule_verb = t("ticket.executed")
    if rule.blank?
      return rule_verb
    end
    case rule[:type]
    when -1
      rule_verb = t("ticket.performed")
      rule_privilege = false
    when 1
      system_rule_path = edit_admin_va_rule_path(rule[:id])
      rule_privilege = privilege?(:manage_dispatch_rules)
    when 4
      system_rule_path = edit_admin_observer_rule_path(rule[:id])
      rule_privilege = privilege?(:manage_dispatch_rules)
    when 3
      system_rule_path = edit_admin_supervisor_rule_path(rule[:id])
      rule_privilege = privilege?(:manage_supervisor_rules)
    else
      rule_privilege = false
    end

    if rule_privilege && rule[:exists]
      rule_verb + link_to(rule[:type_name],system_rule_path, :class => "system-rule-link tooltip", :title => h(rule[:name]), :target => "_blank")
    elsif rule_privilege
      rule_verb + content_tag(:span, h(rule[:type_name]), :title => t("ticket.deleted_rule", :rule_name => h(rule[:name])), :class => "tooltip")
    else
      rule_verb + content_tag(:span, h(rule[:type_name]))
    end
  end

  def format_activity_date(timestamp, format)
    activity_timestamp  = timestamp / ActivityConstants::TIME_MULTIPLIER
    if format
      Time.zone.at(activity_timestamp)
    else
      activity_timestamp
    end
  end

  def formated_date(date_time, options={})
    default_options = {
      :format => :short_day_with_time,
      :include_year => false,
      :include_weekday => true,
      :translate => true
    }
    options = default_options.merge(options)
    time_format = (current_account.date_type(options[:format]) if current_account) || "%a, %-d %b, %Y at %l:%M %p"
    unless options[:include_year]
      time_format = time_format.gsub(/,\s.\b[%Yy]\b/, "") if (date_time.year == Time.now.year)
    end

    unless options[:include_weekday]
      time_format = time_format.gsub(/\A(%a|A),\s/, "")
    end
    final_date = options[:translate] ? (I18n.l date_time , :format => time_format) : (date_time.strftime(time_format))
  end

  def date_range_val(start_date,end_date,additional_options={})
    options = {
      :format => :short_day_separated,
      :include_year => true,
      :translate => false
    }
    options = options.merge(additional_options)
    params[:date_range].blank? ? "#{formated_date(start_date,options)} - #{formated_date(end_date,options)}" :  h(params[:date_range])
  end

  # Get Pref color for individual portal
  def portal_pref(item, type)
   color = current_account.main_portal[:preferences].fetch(type, '')
   if !item[:preferences].blank?
     color = item[:preferences].fetch(type, '')
   end
   sanitize(color)
 end

 # def get_time_in_hours seconds
 #   sprintf( "%0.02f", seconds/3600)
 # end

 def get_time_in_hours seconds
  hh = (seconds/3600).to_i
  mm = ((seconds % 3600)/60.to_f).round

  hh.to_s.rjust(2,'0') + ":" + mm.to_s.rjust(2,'0')
 end

 def get_total_time time_sheets
   total_time_in_sec = total_time_in_seconds(time_sheets)
   get_time_in_hours(total_time_in_sec)
 end

 def total_time_in_seconds time_sheets
  time_sheets.collect{|t| t.running_time}.sum
 end

  #This one checks for installed apps in account
  def dropbox_app_key
    app = installed_apps[:dropbox]
    app.configs[:inputs]['app_key']  unless (app.blank?)
  end

  def cloud_files_installed?
    dropbox_app_key || installed_apps[:box] || installed_apps[:onedrive]
  end

  def get_enabled_cloud_files_app
    array = []
    [:box, :dropbox, :onedrive].each do |c_f|
      array << c_f if installed_apps[c_f]
    end
    array
  end

  def get_app_widget_script(app_name, widget_name, liquid_objs)
    installed_app = installed_apps[app_name.to_sym]
    if installed_app.blank? or installed_app.application.blank?
      return ""
    else
      widget = installed_app.application.widget
      widget_script(installed_app, widget, liquid_objs)
    end
  end

  def widget_script(installed_app, widget, liquid_objs)
    replace_objs = liquid_objs || {}
    replace_objs = replace_objs.merge({"current_user"=>current_user})
    # replace_objs will contain all the necessary liquid parameter's real values that needs to be replaced.
    replace_objs = replace_objs.merge({installed_app.application.name.to_s => installed_app, 'installed_app' => (InstalledAppDrop.new installed_app), "application" => installed_app.application, 'account_id' => current_account.id, 'portal_id' => current_portal.id}) unless installed_app.blank?# Application name based liquid obj values.
    Liquid::Template.parse(widget.script).render(replace_objs, :filters => [Integrations::FDTextFilter]).html_safe  # replace the liquid objs with real values.
  end

  def construct_ui_element(object_name, field_name, field, field_value = "", installed_app=nil, form=nil,disabled=false)
    field_label = t(field[:label])
    dom_type = field[:type]
    required = field[:required]
    rel_value = field[:rel]
    url_autofill_validator = field[:validator_type]
    ghost_value = field[:autofill_text]
    encryption_type = field[:encryption_type]
    element_class   = " #{ (required) ? 'required' : '' }  #{ (url_autofill_validator) ? url_autofill_validator  : '' } #{ dom_type }"
    field_label    += " #{ (required) ? '<span class="required_star">*</span>' : '' }"
    object_name     = "#{object_name.to_s}"
    label = label_tag object_name+"_"+field_name, field_label.html_safe
    dom_type = dom_type.to_s

    case dom_type
      when "text", "number", "email", "multiemail" then
        field_value = field_value.to_s.split(ghost_value).first unless ghost_value.blank?
        element = label + text_field(object_name, field_name, :disabled => disabled, :class => element_class, :value => field_value, :rel => rel_value, "data-ghost-text" => ghost_value)
        element << hidden_field(object_name , :ghostvalue , :value => ghost_value) unless ghost_value.blank?
      when "password" then
        pwd_element_class = " #{ (required) ? 'required' : '' }  text"
        element = label + password_field(object_name, field_name, :type => "password", :class => pwd_element_class, :value => field_value)
        element << hidden_field(object_name , "encryptiontype" , :value => encryption_type) unless encryption_type.blank?
      when "paragraph" then
        element = label + text_area(object_name, field_name, :class => element_class, :value => field_value)
      when "dropdown" then
        choices = [];i=0
        field[:choices].each do |choice|
          choices[i] = (choice.kind_of? Array ) ? [t(choice[0]), choice[1]] : t(choice); i=i+1
        end
        element = label + select(object_name, field_name, choices, {:class => element_class, :selected => field_value},{:disabled => disabled})
      when "custom" then
        rendered_partial = (render :partial => field[:partial], :locals => {:installed_app=>installed_app, :f=>form})
        element = "#{label} #{rendered_partial}"
      when "hidden" then
        element = hidden_field(object_name , field_name , :value => field_value)
      when "checkbox" then
        element = content_tag(:div, check_box(object_name, field_name, :class => element_class, :checked => field_value == "1" ) + '  ' +field_label)
      when "html_paragraph" then
        element = label + text_area(object_name, field_name, :value => field_value)
    end
    element.html_safe
  end

  def construct_ticket_element(form_builder,object_name, field, field_label, dom_type, required, field_value = "", field_name = "", in_portal = false , is_edit = false, pl_value_id=nil)
    dom_type = (field.field_type == "nested_field") ? "nested_field" : dom_type
    element_class   = " #{ (required) ? 'required' : '' } #{ dom_type }"
    element_class  += " required_closure" if (field.required_for_closure && !field.required)
    element_class  += " section_field" if field.section_field?
    field_label    += '<span class="required_star">*</span>'.html_safe if required
    field_label    += "#{add_requester_field}".html_safe if (dom_type == "requester" && !is_edit) #add_requester_field has been type converted to string to handle false conditions
    field_name      = (field_name.blank?) ? field.field_name.html_safe : field_name.html_safe
    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }".html_safe
    label = label_tag (pl_value_id ? object_name+"_"+field.field_name+"_"+pl_value_id :
                                     object_name+"_"+field.field_name),
                      field_label.html_safe,
                      :class => ((field.field_type == "default_company"  && @ticket.new_record?) ? "company_field" : "")
    case dom_type
      when "requester" then
        element = label + content_tag(:div, render(:partial => "/shared/autocomplete_email", :formats => [:html], :locals => { :object_name => object_name, :field => field, :url => requesters_search_autocomplete_index_path }))
        element+= hidden_field(object_name, :requester_id, :value => @item.requester_id)
        element+= label_tag("", "#{add_requester_field}".html_safe,:class => 'hidden') if is_edit
        unless is_edit or params[:format] == 'widget'
          element = add_cc_field_tag element, field
        end
      when "email" then
        element = label + text_field(object_name, field_name, :class => element_class, :value => field_value)
        element = add_cc_field_tag element ,field if (field.portal_cc_field? && !is_edit && controller_name.singularize != "feedback_widget") #dirty fix
        element += add_name_field if !is_edit and !current_user
      when "text", "number", "decimal" then
        element = label + text_field(object_name, field_name, :class => element_class, :value => field_value)
      when "paragraph" then
        element = label + text_area(object_name, field_name, :class => element_class, :value => field_value)
      when "dropdown" then
        if (['default_priority','default_source','default_status', 'default_company'].include?(field.field_type) )
          element = label + select(object_name, field_name, field.html_unescaped_choices(field.field_type == 'default_company' ? @ticket : nil), {:selected => field_value},{:class => element_class})
          #Just avoiding the include_blank here.
        else
          element = label + select(object_name, field_name, field.html_unescaped_choices, { :include_blank => "...", :selected => field_value},{:class => element_class})
        end
      when "dropdown_blank" then
        element = label + select(object_name, field_name,
                                              field.html_unescaped_choices(@ticket),
                                              {:include_blank => "...", :selected => field_value},
                                              {:class => element_class})
      when "nested_field" then
        element = label + nested_field_tag(object_name,
                                            field_name,
                                            field,
                                            { :include_blank => "...",
                                              :selected => field_value,
                                              :pl_value_id => pl_value_id},
                                            {:class => element_class},
                                            field_value,
                                            in_portal,
                                            required)
      when "hidden" then
        element = hidden_field(object_name , field_name , :value => field_value)
      when "checkbox" then
        check_box_html = { :class => element_class }
        if pl_value_id
          id = gsub_id object_name+"_"+field_name+"_"+pl_value_id
          check_box_html.merge!({:id => id})
        end
        checkbox_element = ( required ? ( check_box_tag(%{#{object_name}[#{field_name}]}, 1, !field_value.blank?,  check_box_html)) :
                                          ( check_box(object_name, field_name, check_box_html.merge!({:checked => field_value}) ) ) )
        element = content_tag(:div, (checkbox_element + label).html_safe)
      when "html_paragraph" then
        form_builder.fields_for(:ticket_body, @ticket.ticket_body ) do |builder|
            element = label + builder.text_area(field_name, :class => element_class, :value => field_value, :"data-wrap-font-family" => true )
        end
      when "date" then
      element = label + content_tag(:div, construct_date_field(field_value,
                                                                 object_name,
                                                                 field_name,
                                                                 element_class).html_safe,
                                            :class => "controls input-date-field")
    end
    element_class = (field.has_sections_feature? && (field.section_dropdown? || field.field_type == "default_source")) ? " dynamic_sections" : ""
    company_class = " hide" if field.field_type == "default_company" && @ticket.new_record?
    content_tag :li, element.html_safe, :class => "#{ dom_type } #{ field.field_type } field" + element_class + company_class.to_s
  end


def construct_new_ticket_element_for_google_gadget(form_builder,object_name, field, field_label, dom_type, required, field_value = "", field_name = "", in_portal = false , is_edit = false, pl_value_id=nil)
    dom_type = (field.field_type == "nested_field") ? "nested_field" : dom_type
    element_class   = " #{ (required && !object_name.eql?(:template_data)) ? 'required' : '' } #{ dom_type }"
    element_class  += " required_closure" if (field.required_for_closure && !field.required)
    element_class  += " section_field" if field.section_field?
    field_label    += '<span class="required_star">*</span>'.html_safe if required
    field_label    += "#{add_requester_field}".html_safe if (dom_type == "requester" && !is_edit) #add_requester_field has been type converted to string to handle false conditions
    field_name      = (field_name.blank?) ? field.field_name.html_safe : field_name.html_safe
    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }".html_safe
    label = label_tag (pl_value_id ? object_name+"_"+field.field_name+"_"+pl_value_id :
                                     object_name+"_"+field.field_name),
                      field_label.html_safe,
                      :class => ((field.field_type == "default_company" && @ticket.new_record?) ? "company_field" : "")
    choices = field.choices
    description = field.description
    case dom_type
      when "old_requester" then
        element = label + content_tag(:div, render(:partial => "/shared/autocomplete_email", :formats => [:html], :locals => { :object_name => object_name, :field => field, :url => requesters_search_autocomplete_index_path }))
        element+= hidden_field(object_name, :requester_id, :value => @item.requester_id)
        element+= label_tag("", "#{add_requester_field}".html_safe,:class => 'hidden') if is_edit
        unless is_edit or params[:format] == 'widget'
          element = add_cc_field_tag element, field
        end
      when "requester" then
         search_req =   "#{add_requester_field}".html_safe #if (!is_edit)
        unless is_edit or params[:format] == 'widget'
          show_cc = show_cc_field  field
        end
            element = render(:partial => "/helpdesk/tickets/ticket_widget/requester", :formats => [:html], :locals => {:search_req => search_req , :placeholder => description, :show_cc => show_cc, :is_edit => is_edit, :object_name => object_name})
            element+= hidden_field(object_name, :requester_id, :value => @item.requester_id)
      when "email" then
        element = label + text_field(object_name, field_name, :class => element_class, :value => field_value)
        element = add_cc_field_tag element ,field if (field.portal_cc_field? && !is_edit && controller_name.singularize != "feedback_widget") #dirty fix
        element += add_name_field if !is_edit and !current_user
      when "text", "number", "decimal" then
        element = label + text_field(object_name, field_name, :class => element_class, :value => "#{field_value}")
      when "paragraph" then
        element = label + text_area(object_name, field_name, :class => element_class, :value => field_value)
      when "dropdown" then
        if (['default_priority','default_source','default_status'].include?(field.field_type) )
          element = label + select(object_name, field_name, field.html_unescaped_choices, {:selected => field_value},{:class => element_class + " select2", "data-domhelper-name" => "ticket-properties-" + field_name })
          #Just avoiding the include_blank here.
        else
          element = label + select(object_name, field_name, field.html_unescaped_choices, { :include_blank => "...", :selected => field_value},{:class => element_class + " select2", "data-domhelper-name" => "ticket-properties-" + field_name })
        end
      when "dropdown_blank" then
        dropdown_choices = field.html_unescaped_choices(@ticket)
        disabled = true if field.field_type == "default_company" && dropdown_choices.empty?
        element = label + select(object_name, field_name,
                                              dropdown_choices,
                                              {:include_blank => "...", :selected => field_value},
                                              {:class => element_class + " select2",
                                               :disabled => disabled,
                                               "data-domhelper-name" => "ticket-properties-" + field_name })
      when "hidden" then
        element = hidden_field(object_name , field_name , :value => field_value)
      when "checkbox" then
        check_box_html = { :class => element_class }
        if pl_value_id
          id = gsub_id object_name+"_"+field_name+"_"+pl_value_id
          check_box_html.merge!({:id => id})
        end
        checkbox_element = ( required ? ( check_box_tag(%{#{object_name}[#{field_name}]}, 1, !field_value.blank?,  check_box_html)) :
                                          ( check_box(object_name, field_name, check_box_html.merge!({:checked => field_value}) ) ) )
        element = content_tag(:div, (checkbox_element + label).html_safe, :class => "checkbox-wrapper")
      when "html_paragraph" then
         element = label
         redactor_wrapper = ""
        form_builder.fields_for(:ticket_body, @ticket.ticket_body ) do |builder|
            redactor_wrapper = builder.text_area(field_name, :class => element_class, :value => field_value, :"data-wrap-font-family" => true )
        end
            element += content_tag(:div, redactor_wrapper, :class => "redactor_wrapper")
      when "date" then
        element = label + content_tag(:div, construct_date_field(field_value,
                                                                 object_name,
                                                                 field_name,
                                                                 element_class).html_safe,
                                            :class => "controls input-date-field")

    end
    element_class = (field.has_sections_feature? && (field.section_dropdown? || field.field_type == "default_source")) ? " dynamic_sections" : ""
    company_class = " hide" if field.field_type == "default_company" && (@ticket.new_record? || dropdown_choices.empty?)
    content_tag :li, element.html_safe, :class => "#{ dom_type } #{ field.field_type } field" + element_class + company_class.to_s
  end

  def construct_new_ticket_element(form_builder,object_name, field, field_label, dom_type, required, field_value = "", field_name = "", in_portal = false , is_edit = false, pl_value_id=nil)
    return "" if field.secure_field? || (field.encrypted_field? && !current_account.falcon_and_encrypted_fields_enabled?)

    dom_type = (field.field_type == "nested_field") ? "nested_field" : dom_type
    element_class   = " #{ (required && !object_name.eql?(:template_data)) ?
                      (field.field_type == "default_description" ? 'required_redactor' : 'required') : '' } #{ dom_type }"
    element_class  += " required_closure" if (field.required_for_closure && !field.required)
    element_class  += " section_field" if field.section_field?
    field_label     = '<span class="ficon-encryption-lock"></span>' + field_label if field.encrypted_field? && current_account.falcon_and_encrypted_fields_enabled?
    field_label    += '<span class="required_star">*</span>'.html_safe if required
    field_label    += "#{add_requester_field}".html_safe if (dom_type == "requester" && !is_edit) #add_requester_field has been type converted to string to handle false conditions
    field_name      = (field_name.blank?) ? field.field_name.html_safe : field_name.html_safe
    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }".html_safe
    label = label_tag (pl_value_id ? object_name+"_"+field.field_name+"_"+pl_value_id :
                                     object_name+"_"+field.field_name),
                      field_label.html_safe,
                      :class => ((field.field_type == "default_company" && @ticket.new_record?) ? "company_field" : "")
    choices = field.choices
    description = field.description
    case dom_type
      when "old_requester" then
        element = label + content_tag(:div, render(:partial => "/shared/autocomplete_email", :formats => [:html], :locals => { :object_name => object_name, :field => field, :url => requesters_search_autocomplete_index_path }))
        element+= hidden_field(object_name, :requester_id, :value => @item.requester_id)
        element+= label_tag("", "#{add_requester_field}".html_safe,:class => 'hidden') if is_edit
        unless is_edit or params[:format] == 'widget'
          element = add_cc_field_tag element, field
        end
      when "requester" then
         search_req =   "#{add_requester_field}".html_safe #if (!is_edit)
        unless is_edit or params[:format] == 'widget' or @parent_id#(for child template)
          show_cc = show_cc_field  field
        end
        element = render(:partial => "/helpdesk/tickets/ticket_widget/requester", :formats => [:html], :locals => {:search_req => search_req , :placeholder => description, :show_cc => show_cc, :is_edit => is_edit, :object_name => object_name})
        value   = object_name.eql?("template_data") ? @item.template_data[:requester_id] : @item.requester_id
        element+= hidden_field(object_name, :requester_id, :value => value)
      when "email" then
        element = label + text_field(object_name, field_name, :class => element_class, :value => field_value)
        element = add_cc_field_tag element ,field if (field.portal_cc_field? && !is_edit && controller_name.singularize != "feedback_widget") #dirty fix
        element += add_name_field if !is_edit and !current_user
      when "text", "number", "decimal", "encrypted_text" then
        element = label + text_field(object_name, field_name, :class => element_class, :value => "#{field_value}")
      when "paragraph" then
        element = label + text_area(object_name, field_name, :class => element_class, :value => field_value)
      when "dropdown" then
        if (['default_priority','default_source','default_status'].include?(field.field_type) )
          element = label + select(object_name, field_name, field.html_unescaped_choices, {:selected => field_value},{:class => element_class + " select2", "data-domhelper-name" => "ticket-properties-" + field_name })
          #Just avoiding the include_blank here.
        else
          element = label + select(object_name, field_name, field.html_unescaped_choices, { :include_blank => "...", :selected => field_value},{:class => element_class + " select2", "data-domhelper-name" => "ticket-properties-" + field_name })
        end
      when "dropdown_blank" then
        dropdown_choices = field.html_unescaped_choices(@ticket)
        disabled = true if field.field_type == "default_company" &&
                                               dropdown_choices.length <= 1
        element = label + select(object_name, field_name,
                                              dropdown_choices,
                                              {:include_blank => "...", :selected => field_value},
                                              {:class => element_class + " select2",
                                               :disabled => disabled,
                                               "data-domhelper-name" => "ticket-properties-" + field_name })
      when "nested_field" then
        element =  new_nested_field_tag(label, object_name,
                                            field_name,
                                            field,
                                            { :include_blank => "...",
                                              :selected => field_value,
                                              :pl_value_id => pl_value_id},
                                            {:class => element_class + " select2"},
                                            field_value,
                                            in_portal,
                                            required)
    when 'template_source_dropdown' then
      default_sources = TicketConstants.source_names
      allowed_choices = [default_sources[2]] + [default_sources[9]] + Helpdesk::Source.visible_custom_sources.map { |ch| [ch.name, ch.account_choice_id] }
      element = label + select(object_name, field_name, allowed_choices, { include_blank: '...', selected: field_value }, class: element_class + ' select2', 'data-domhelper-name': 'ticket-properties-' + field_name)
      when "hidden" then
        element = hidden_field(object_name , field_name , :value => field_value)
      when "checkbox" then
        check_box_html = { :class => element_class }
        if pl_value_id
          id = gsub_id object_name+"_"+field_name+"_"+pl_value_id
          check_box_html.merge!({:id => id})
        end
        checkbox_element = ( required ? ( check_box_tag(%{#{object_name}[#{field_name}]}, 1, !field_value.blank?,  check_box_html)) :
                                          ( check_box(object_name, field_name, check_box_html.merge!({:checked => field_value}) ) ) )
        element = content_tag(:div, (checkbox_element + label).html_safe, :class => "checkbox-wrapper")
      when "html_paragraph" then
        element = label
        redactor_wrapper = ""
        element_class += " ta_insert_cr" if field.field_type == "default_description"
        editor_type = object_name.eql?("template_data") ? :template : :ticket
        id,name = "#{object_name}_ticket_body_attributes_description_html", "#{object_name}[ticket_body_attributes][description_html]"
        form_builder.fields_for(:ticket_body, @ticket.ticket_body ) do |builder|
          redactor_wrapper = builder.text_area(field_name, :class => element_class, :value => field_value, :"data-wrap-font-family" => true, :"editor-type" => editor_type, :id => id, :name => name)
        end
        redactor_wrapper += render(:partial => "/helpdesk/tickets/ticket_widget/new_ticket_attachment", :formats => [:html], :locals => {:object_name => object_name})
        redactor_wrapper += content_tag(:div, render(:partial => "helpdesk/tickets/show/editor_insert_buttons",
                  :locals => {:cntid => 'tkt-cr'}), :class => "request_panel") if field.field_type == "default_description"
        element += content_tag(:div, redactor_wrapper, :class => "redactor_wrapper")
      when "date" then
        element = label + content_tag(:div, construct_date_field(field_value,
                                                                 object_name,
                                                                 field_name,
                                                                 element_class).html_safe,
                                            :class => "controls input-date-field")
    when 'file' then
      element = hidden_field(object_name, field_name, value: field_value)

    end
    fd_class = "#{ dom_type } #{ field.field_type } field"
    fd_class += " dynamic_sections" if (field.has_sections_feature? && (field.section_dropdown? || field.field_type == "default_source"))
    fd_class += " hide" if field.field_type == "default_company" &&
                                               (@ticket.new_record? ||
                                               dropdown_choices.length <= 1)
    fd_class += " tkt_cr_wrap" if field.field_type == "default_description"
    content_tag :li, element.html_safe, :class => fd_class
  end

  def show_cc_field field
      if current_user && current_user.agent?
      element  = true
    elsif current_user && current_user.customer? && field.all_cc_in_portal?
      element  = true
    else
      element = false
    end
    return element
  end

  def construct_date_field(field_value, object_name, field_name, element_class)
    date_format = AccountConstants::DATEFORMATS[Account.current.account_additional_settings.date_format]
    field_value = formatted_date(field_value) if !object_name.include?("template_data") and field_value.present?
    text_field_tag("#{object_name}[#{field_name}]", field_value,
              {:class => "#{element_class} datepicker_popover",
                :readonly => true,
                :'data-show-image' => "true",
                :'data-date-format' => AccountConstants::DATA_DATEFORMATS[date_format][:datepicker] })
  end

  def construct_section_fields(f, field, is_edit, item, required)
    section_container = ""
    field.picklist_values.includes(:section).each do |picklist|
      next if picklist.section.blank?
      section_elements = ""
      picklist.section_ticket_fields.each do |section_tkt_field|
        if is_edit || required
          section_field_value = item.is_a?(Helpdesk::Ticket) ? item.safe_send(section_tkt_field.field_name) :
            item.custom_field_value(section_tkt_field.field_name)
          section_field_value = nested_ticket_field_value(item,
                                  section_tkt_field) if section_tkt_field.field_type == "nested_field"
        elsif !params[:topic_id].blank?
          section_field_value = item[section_tkt_field.field_name]
        end
        field_label = (section_tkt_field.label).html_safe
        section_elements += construct_ticket_element(f, :helpdesk_ticket,
                                                        section_tkt_field,
                                                        field_label,
                                                        section_tkt_field.dom_type,
                                                        section_tkt_field.required,
                                                        section_field_value,
                                                        "",
                                                        false,
                                                        is_edit,
                                                        picklist.id.to_s)
      end
      section_container += text_area_tag "", content_tag(:ul, section_elements.html_safe.gsub("</textarea>", "&lt/textarea&gt"),
                                                               :class => "ticket_section"),
                                            :id => "picklist_section_#{picklist.id}",
                                            :disabled => true,
                                            :class => "hide"
    end
    section_container
  end

  def construct_new_section_fields(f, object_name, field, is_edit, item, required)
    section_container = ""
    field.picklist_values_with_sections.each do |picklist|
      next if picklist.section.blank?
      section_elements = ""
      picklist.section_ticket_fields.each do |section_tkt_field|
        if is_edit || params[:template_form] || required
          section_field_value = if item.is_a?(Helpdesk::TicketTemplate)
            item.template_data[section_tkt_field.field_name]
          elsif item.is_a?(Helpdesk::Ticket)
            item.safe_send(section_tkt_field.field_name)
          else
            item.custom_field_value(section_tkt_field.field_name)
          end
          section_field_value = nested_ticket_field_value(item,
                                  section_tkt_field) if section_tkt_field.field_type == "nested_field"
        elsif !params[:topic_id].blank?
          section_field_value = item[section_tkt_field.field_name]
        end
        field_label = (section_tkt_field.label).html_safe
        section_elements += construct_new_ticket_element(f, object_name,
                                                        section_tkt_field,
                                                        field_label,
                                                        section_tkt_field.dom_type,
                                                        section_tkt_field.required,
                                                        section_field_value,
                                                        "",
                                                        false,
                                                        is_edit,
                                                        picklist.id.to_s)
      end
      section_container += text_area_tag "", content_tag(:ul, section_elements.html_safe.gsub("</textarea>", "&lt/textarea&gt"),
                                                               :class => "ticket_section"),
                                            :id => "picklist_section_#{picklist.id}",
                                            :disabled => true,
                                            :class => "hide"
    end
    section_container
  end

  def add_cc_field_tag element , field
    if current_user && current_user.agent?
      element  = element + content_tag(:div, render(:partial => "/shared/cc_email_all", :formats => [:html]))
    elsif current_user && current_user.customer? && field.all_cc_in_portal?
      element  = element + content_tag(:div, render(:partial => "/shared/cc_email_all", :formats => [:html]))
    else
      element  = element + content_tag(:div, render(:partial => "/shared/cc_email", :formats => [:html])) if (current_user && field.company_cc_in_portal? && current_user.company)
    end
    return element
  end

  def add_requester_field
    render(:partial => "/shared/add_requester") if (params[:format] != 'widget' && privilege?(:manage_contacts))
  end

  def add_name_field
    content_tag(:li, (content_tag(:div, render(:partial => "/shared/name_field"))).to_s,
                :id => "name_field", :class => "hide") unless current_user
  end

  # The field_value(init value) for the nested field should be in the the following format
  # { :category_val => "", :subcategory_val => "", :item_val => "" }
  def nested_field_tag(_name, _fieldname, _field, _opt = {}, _htmlopts = {}, _field_values = {}, in_portal = false, required)
  _javascript_opts = {
      :data_tree => _field.nested_choices,
      :initValues => _field_values,
      :disable_children => false
    }.merge!(_opt)
    if _opt[:pl_value_id].present?
      _htmlopts.merge!({:id => gsub_id("#{_name}_#{_fieldname}_#{_opt[:pl_value_id]}")})
      _category = select(_name, _fieldname, _field.html_unescaped_choices, _opt, _htmlopts)
      _field.nested_levels.each do |l|
        _htmlopts.merge!({:id => gsub_id("#{_name}_#{l[:name]}_#{_opt[:pl_value_id]}")})
        _javascript_opts[(l[:level] == 2) ? :subcategory_id : :item_id] = gsub_id(_name +"_"+ l[:name]+"_"+_opt[:pl_value_id])
        _category += content_tag :div, content_tag(:label, (nested_field_label(l[(!in_portal)? :label : :label_in_portal],required)).html_safe) + select(_name, l[:name], [], _opt, _htmlopts), :class => "level_#{l[:level]}"
      end
      (_category + javascript_tag("jQuery('##{gsub_id(_name +"_"+ _fieldname+"_"+_opt[:pl_value_id])}').nested_select_tag(#{_javascript_opts.to_json});")).html_safe
    else
      _category = select(_name, _fieldname, _field.html_unescaped_choices, _opt, _htmlopts)
      _field.nested_levels.each do |l|
        _javascript_opts[(l[:level] == 2) ? :subcategory_id : :item_id] = gsub_id(_name +"_"+ l[:name])
        _category += content_tag :div, content_tag(:label, (nested_field_label(l[(!in_portal)? :label : :label_in_portal],required)).html_safe) + select(_name, l[:name], [], _opt, _htmlopts), :class => "level_#{l[:level]}"
      end
      (_category + javascript_tag("jQuery('##{gsub_id(_name +"_"+ _fieldname)}').nested_select_tag(#{_javascript_opts.to_json});")).html_safe
      end
  end

   def new_nested_field_tag(label, _name, _fieldname, _field, _opt = {}, _htmlopts = {}, _field_values = {}, in_portal = false, required)
  _javascript_opts = {
      :data_tree => _field.nested_choices,
      :initValues => _field_values,
      :disable_children => false
    }.merge!(_opt)
    if _opt[:pl_value_id].present?
      _htmlopts.merge!({:id => gsub_id("#{_name}_#{_fieldname}_#{_opt[:pl_value_id]}")})
      _main_field = content_tag :div, label + select(_name, _fieldname, _field.html_unescaped_choices, _opt, _htmlopts), :class => "main_field"
      # _category = select(_name, _fieldname, _field.html_unescaped_choices, _opt, _htmlopts)
      _category =  _main_field
      _field.nested_levels.each do |l|
        _htmlopts.merge!({:id => gsub_id("#{_name}_#{l[:name]}_#{_opt[:pl_value_id]}")})
        _javascript_opts[(l[:level] == 2) ? :subcategory_id : :item_id] = gsub_id(_name +"_"+ l[:name]+"_"+_opt[:pl_value_id])
        _category += content_tag :div, content_tag(:label, (nested_field_label(l[(!in_portal)? :label : :label_in_portal],required)).html_safe) + select(_name, l[:name], [], _opt, _htmlopts), :class => "level_#{l[:level]}"
      end
      (_category + javascript_tag("jQuery('##{gsub_id(_name +"_"+ _fieldname+"_"+_opt[:pl_value_id])}').nested_select_tag(#{_javascript_opts.to_json});")).html_safe
    else
      _main_field = content_tag :div, label + select(_name, _fieldname, _field.html_unescaped_choices, _opt, _htmlopts), :class => "main_field"
      # _category = select(_name, _fieldname, _field.html_unescaped_choices, _opt, _htmlopts)
       _category =  _main_field
      _field.nested_levels.each do |l|
        _javascript_opts[(l[:level] == 2) ? :subcategory_id : :item_id] = gsub_id(_name +"_"+ l[:name])
        _category += content_tag :div, content_tag(:label, (nested_field_label(l[(!in_portal)? :label : :label_in_portal],required)).html_safe) + select(_name, l[:name], [], _opt, _htmlopts), :class => "level_#{l[:level]}"
      end
      (_category + javascript_tag("jQuery('##{gsub_id(_name +"_"+ _fieldname)}').nested_select_tag(#{_javascript_opts.to_json});")).html_safe
      end
  end

  def gsub_id(text)
    text.gsub('[','_').gsub(']','')
  end

  def nested_field_label(label, required)
    field_label = label
    field_label += '<span class="required_star">*</span>'.html_safe if required
    return field_label
  end

  def construct_ticket_text_element(object_name, field, field_label, dom_type, required, field_value = "", field_name = "")
    field_name      = (field_name.blank?) ? field.field_name : field_name
    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }"

    label = label_tag object_name+"_"+field.field_name, field_label, :class => "name_label"

    if(field.field_type == "nested_field")
      unless field_value[:category_val].blank?
        element = label + label_tag(field_name, field_value[:category_val], :class => "value_label")
        field.nested_levels.each do |l|
          _name = label_tag("", l[:label_in_portal], :class => "name_label")
          _field_value = field_value[(l[:level] == 2) ? :subcategory_val : (l[:level] == 3) ? :item_val : ""]
          _value = label_tag(field_name, _field_value, :class => "value_label")
          element += content_tag(:div, _name + _value, :class => "tabbed") unless (_field_value.blank? || field_value[:subcategory_val].blank?)
        end
      end
    elsif(field.field_type == "default_status")
      field_value = field.dropdown_selected(field.all_status_choices, field_value) if(dom_type == "dropdown") || (dom_type == "dropdown_blank")
      element = label + label_tag(field_name, field_value, :class => "value_label")
    else
      field_value = field.dropdown_selected(field.html_unescaped_choices, field_value) if(dom_type == "dropdown") || (dom_type == "dropdown_blank")
      element = label + label_tag(field_name, field_value, :class => "value_label")
    end

    element unless display_tag?(element,field,field_value)
  end

  def display_tag?(element, field, field_value)
    (element.blank? || field_value.nil? || field_value == "" || field_value == "..." || ((field.field_type == "custom_checkbox") && !field_value))
  end

  def pageless(total_pages, url, message=t("loading.items"), params = {}, data_type = "html", complete = "")
    opts = {
      :totalPages   => total_pages,
      :url          => url,
      :loaderMsg    => message,
      :params       => params,
      :currentPage  => 1,
      :dataType     => data_type,
      :complete     => complete
    }
    javascript_tag("jQuery('#Pages').pageless(#{opts.to_json});")
  end

  def load_more(opts = {})
    javascript_tag("setTimeout(function(){jQuery('#{opts[:container]}').loadmore(#{opts.to_json})}, 500);")
  end

  def render_page
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end

  def email_regex
    AccountConstants::EMAIL_SCANNER.source
  end

  def plain_email_regex
    AccountConstants::EMAIL_REGEX.source
  end

  def nodejs_url namespace
    nodejs_port = Rails.env.development? ? 5000 : (request.ssl? ? 2050 : 1050)
    "#{request.protocol}#{request.host}:#{nodejs_port}/#{namespace}"
  end

  def assumed_identity_message
    _output = []
    if current_user && is_assumed_user?
      _output << %( <div class="alert-assume-agent alert-solid"> )
      _output << %( #{t('header.assumed_text')} <b> #{current_user.name}</b> - )
      _output << link_to(t('revert_identity_link_msg'), revert_identity_users_path, :class => "link")
      _output << %( </div> )
    end
    _output.join("").html_safe
  end

  def admin_account_verification_message
    render partial: "shared/account_verification_message" unless current_account.verified?
  end

  def get_logo
    unless @account.main_portal.logo.blank?
      return @account.main_portal.logo.content.url(:logo)
    end
    return "/assets/logo.png?721013"
  end

  def get_base_domain
    AppConfig['base_domain'][Rails.env]
  end

  def show_upgrade_plan?
    current_user.privilege?(:manage_account) && (current_account.subscription.free? || current_account.subscription.trial?)
  end

  def attachment_size
    Account.current.attachment_limit if Account.current
  end

  private

    def forums_visibility?
      current_account.features_included?(:forums) && allowed_in_portal?(:open_forums) && privilege?(:view_forums)
    end

    def set_twitter_url_in_redis(auth_redirect_url, account_url, state)
      key = "#{Social::Twitter::Constants::COMMON_REDIRECT_REDIS_PREFIX}:#{state}"
      set_others_redis_key(key, "#{account_url}", 180)
      onclick_strategy(auth_redirect_url)
    end

    def onclick_strategy(auth_redirect_url)
      if current_account.falcon_ui_enabled?(current_user)
        "parent.location.href='#{auth_redirect_url}'"
      else
        "window.location.href='#{auth_redirect_url}'"
      end
    end

    def social_tab
      view_social_tab = can_view_social?
      handles_present = handles_associated?
      if handles_present
        ['/social/streams', :social,     view_social_tab]
      elsif !handles_present
        ['/social/welcome', :social,     can_view_welcome_page?]
      else
        ['#', :social, false]
      end
    end

    def can_view_social?
      current_account.basic_twitter_enabled? && privilege?(:manage_tickets) &&
          current_account.social_tab_enabled?
    end

    def social_enabled?
      settings = current_account.account_additional_settings.additional_settings
      settings.blank? || settings[:enable_social].nil? || settings[:enable_social]
    end

    def handles_associated?
      !current_account.twitter_handles_from_cache.blank?
    end

    def can_view_welcome_page?
      privilege?(:admin_tasks) && can_view_social? && social_enabled?
    end

    def inm_tour_button(text,topic_id)
      link_to(text, '#', rel: 'guided-inlinemanual', 'data-topic-id': topic_id, class: 'inm_tour_button')
    end

  def check_fb_reauth_required
    fb_page = current_account.fb_reauth_check_from_cache
    if fb_page
      return content_tag('div', "<a href='javascript:void(0)'></a> #{t('facebook_reauth')} <a href='/social/facebook' target='_blank'> #{t('reauthorize_facebook')} </a>".html_safe, :class =>
        "alert-message block-message warning full-width")
    end
    return
  end


  def check_custom_mailbox_status
    if feature?(:mailbox)
      custom_mail_box_faliure = current_account.custom_mailbox_errors_present
      if custom_mail_box_faliure
        return content_tag('div', "<a href='javascript:void(0)'></a> #{t('custom_mailbox_error')} <a href='/admin/email_configs' target='_blank'> #{t('imap_mailbox_error')} </a>".html_safe, :class =>
            "alert-message block-message warning full-width")
      end
      return
    end
  end

  #Checks if Email was disabled by Freshpipe for running migrations
  def check_email_disabled_by_pipe
    if current_account.launched?(:disable_emails)
      return content_tag('div', "#{t('freshpipe_email_disabled')}".html_safe, :class =>
        "alert-message block-message warning full-width")
    end
  end

  def fb_realtime_msg_disabled
    if current_account.fb_realtime_msg_from_cache
      return content_tag('div', "#{t('fb_realtime_enable')}".html_safe, :class =>
        "alert-message block-message full-width")
    end
  end

  def check_twitter_reauth_required
    twt_handle = current_account.twitter_reauth_check_from_cache
    if twt_handle
      return content_tag('div', "<a href='javascript:void(0)'></a> #{t('twitter_reauth')} <a href='/admin/social/streams' target='_blank'> #{t('reauthorize_twitter')} </a>".html_safe, :class =>
        "alert-message block-message warning full-width")
    end
    return
  end

  def check_smart_filter_revoked
    if current_account.twitter_smart_filter_revoked?
      return content_tag('div', "#{t('smart_filter_disabled')}".html_safe, :class =>
        "alert-message block-message full-width")
    end
  end

  def social_reauth_required
    fb_reauth = current_account.fb_reauth_check_from_cache
    twitter_reauth = current_account.twitter_reauth_check_from_cache
    if fb_reauth or twitter_reauth
      reauth_alert = "<div class ='alert-message block-message warning full-width'>"
      reauth_alert = "#{reauth_alert} <div><a href='/admin/social/streams' target='_blank'>Reauthorize your twitter account</a></div>" if twitter_reauth
      reauth_alert = "#{reauth_alert} <div><a href='/social/facebook' target='_blank'>Reauthorize your facebook account</a></div>" if fb_reauth
      reauth_alert = "#{reauth_alert} </div>"
      reauth_alert.html_safe
    end
  end

  # This helper is for the partial expanded/_ticket.html.erb
  def requester(ticket)
    if privilege?(:view_contacts)
      "<a class='user_name' href='/users/#{ticket.requester.id}' target='_blank' data-pjax='#body-container' data-contact-id='#{ticket.requester.id}' data-contact-url='/contacts/#{ticket.requester.id}/hover_card' rel='contact-hover'>
          <span class='emphasize'>#{h(ticket.requester.display_name)}</span>
       </a>".html_safe
    else
      "<span class='user_name emphasize'>#{h(ticket.requester.display_name)}</span>".html_safe
    end
  end

  # This helper is for the partial expanded/_ticket.html.erb
  def quick_action
    privilege?(:edit_ticket_properties) && !collab_filter_enabled_for?(@current_view) ? 'quick-action dynamic-menu' : ''
  end

  def will_paginate(collection_or_options = nil, options = {})
    if collection_or_options.is_a? Hash
      options, collection_or_options = collection_or_options, nil
    end
    super *[collection_or_options, options].compact
  end

  def ilos_widget( entity_id, location)
    ilos_id = (location == "portal_ticket" || location == "portal_forum") ? "ilos-btn-portal" : "ilos-btn-agent"
    ilos_widget_html =
      %Q{<a class='btn btn-flat' href='#{integrations_ilos_popupbox_path}?ilos_entity_id=#{entity_id}&location=#{location}' title='#{t('integrations.ilos.messages.recording_details')}' id='#{ilos_id}' rel='freshdialog' data-target='#ilos-video-recorder' data-width='430' data-submit-label='#{t('integrations.ilos.messages.start_recording')}' data-close-label='#{t('integrations.ilos.messages.cancel_recording')}'><img id='ilos-image' src='/glyphs/vectors/ilos-icon.svg' alt='ilos'>#{t('integrations.ilos.messages.record_screen')}</a>}

    ilos_widget_html.html_safe
  end

  def shortcut(key)
    Shortcut.get(key)
  end

  def shortcuts_enabled?
    logged_in? and current_user.agent? and current_user.agent.shortcuts_enabled?
  end

  def email_template_settings
    current_account.account_additional_settings.email_template_settings.to_json
  end

  def current_browser
    UserAgent.parse(request.user_agent).browser
  end

  def current_platform
    os = UserAgent.parse(request.user_agent).os || 'windows'
    ['windows', 'mac', 'linux'].each do |v|
      return v if os.downcase.include?(v)
    end

    return nil
  end

  def modifier(key)
    platform = current_platform || "windows"
    Shortcut::MODIFIER_KEYS[key.to_sym][platform.to_sym].html_safe
  end

  def moderation_enabled?
    current_account.features?(:moderate_all_posts) || current_account.features?(:moderate_posts_with_links)
  end

  def font_icon(name, opts = {})
    opts[:class] = font_class(name, opts[:size], opts[:class])
    content_tag :i, "", opts
  end

  def font_class(name, size = nil, more_classes = "")
    _class = []
    _class << "ficon-#{name.to_s}"
    _class << "fsize-#{size}" if size.present?
    _class << more_classes
    _class.join(" ")
  end
  # ITIL Related Methods starts here

  def generate_breadcrumbs(params, form=nil, *opt)
    ""
  end

  def load_manifest
    ASSET_MANIFEST.replace({
      :js => AssetLoader.js_assets,
      # :css => AssetLoader.css_assets
      :css => {}
    })
  end

  def asset_manifest(type = :js)
    return {} unless [:js, :css].include?(type)
    load_manifest if ASSET_MANIFEST.blank? and !Rails.env.development?
    Rails.env.development? ? AssetLoader.safe_send("#{type}_assets") : ASSET_MANIFEST[type]
  end

  def asset_host_url
    return "" if Rails.env.development? || Rails.env.test?
    ActionController::Base.asset_host.yield
  end

  # ITIL Related Methods ends here

  #Helper method for rendering only base error messages
  def base_error_messages obj
    if obj.errors.present?
      error_list = obj.errors[:base].collect{ |msg| content_tag('li', msg)}.join(" ").html_safe
      content_tag('div', content_tag('ul', error_list), :id => "errorExplanation", :class => "errorExplanation")
    end
  end

  def tabs_for( *options, &block )
    raise ArgumentError, "Missing block" unless block_given?
    raw TabHelper::TabsRenderer.new( *options, &block ).render
  end

  def fd_node_auth_params
    aes = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    aes.encrypt
    aes.key = Digest::SHA256.digest(FdNodeConfig["key"])
    aes.iv  = FdNodeConfig["iv"]

    account_data = {
      :account_id => current_user.account_id,
      :user_id    => current_user.id,
      :features => current_account.node_feature_list
    }.to_json
    encoded_data = Base64.encode64(aes.update(account_data) + aes.final)
    return encoded_data.to_json.html_safe
  end

  def password_policies_for_popover
    return "" if (@password_policy.nil? or @password_policy.new_record?)
    list = Proc.new do
      @password_policy.policies.collect do |policy|
        case policy
        when :minimum_characters
          concat(content_tag :li, t("admin.security.password_policy_popover.#{policy.to_s}", :count => @password_policy.configs[policy.to_s]) )
        when :cannot_contain_user_name, :atleast_an_alphabet_and_number,
          :have_mixed_case, :have_special_character, :cannot_be_same_as_past_passwords
          concat(content_tag :li, t("admin.security.password_policy_popover.#{policy.to_s}") )
        end
      end
    end

    content_tag :ul, &list
  end

  def fd_socket_host
    "#{request.protocol}#{FdNodeConfig["socket_host"]}"
  end

  def cti_app
    @cti_app ||= current_account.cti_installed_app_from_cache if current_account.features?(:cti)
    @cti_app
  end

  def cti_configs
    if cti_app.present?
      cti_app.configs
    end
  end

  def cti_phone_old_number
    cti_phone_redis_key = Redis::RedisKeys::INTEGRATIONS_CTI_OLD_PHONE % { :account_id => current_account.id, :user_id => current_user.id }
    get_integ_redis_key(cti_phone_redis_key)
  end

  def softfone_enabled?
    if cti_app.present?
      cti_configs[:inputs]["softfone_enabled"].to_bool
    end
  end

  def show_onboarding?
    user_trigger = !is_assumed_user? && current_user.login_count <= 2  && current_user.agent.onboarding_completed?
    (current_user.privilege?(:admin_tasks))  ?  user_trigger && current_account.subscription.trial?  :  user_trigger
  end

  def inline_manual_people_tracing
    role = current_user.privilege?(:admin_tasks) ? "admin" : "agent"
    ui_preference = current_account.falcon_ui_enabled?(current_user) ? 'mint' : 'oldui'
    state  = current_account.subscription.state
    bucket = current_account.account_additional_settings.additional_settings[:announcement_bucket].to_s
    bucket_split = split_with_separator bucket
    features_to_send = features_for_inline_manual
    roles_to_send = [[ui_preference],[role,state],bucket_split,features_to_send].reduce([], :concat)
    inline_manual_people_tracing = {
      :uid      => current_user.id,
      :name     => current_account.full_domain,
      :created  => current_account.created_at.to_i,
      :updated  => current_user.last_login_at.to_i,
      :plan     => Subscription.fetch_by_account_id(current_account.id).subscription_plan_from_cache.display_name,
      :roles    => roles_to_send
    }
    unless current_account.opt_out_analytics_enabled?
      inline_manual_people_tracing.merge!({
        :email    => current_user.email,
        :username => current_user.name
      })
    end
    inline_manual_people_tracing
  end

  def features_for_inline_manual
    enabled_features = INLINE_MANUAL_FEATURES.select {|feature_name| current_account.send("#{feature_name}_enabled?") if current_account.respond_to? "#{feature_name}_enabled?"}
    
    #Maximum of 17 features can be sent to inline manual
    enabled_features = enabled_features[0..INLINE_MANUAL_FEATURE_THRESHOLDS[:max_count]-1]

    #Maximum of 24 characters per feature name 
    enabled_features.map! {|feature_name| feature_name[0..INLINE_MANUAL_FEATURE_THRESHOLDS[:char_length]-1]}
  end

  def description_attachment params = {}
    render :partial => "helpdesk/tickets/description_attachment", :locals => {:filename => params[:filename], :value => params[:value], :name => params[:name]}
  end

  def collab_ticket_view?
    current_account.collaboration_enabled? and @collab_context
  end

  def falcon_enabled?
    Rails.logger.warn "FALCON HELPER METHOD :: falcon_enabled? :: #{caller[0..2]}"
    true
  end

  def admin_only_falcon_enabled?
    Rails.logger.warn "FALCON HELPER METHOD :: admin_only_falcon_enabled? :: #{caller[0..2]}"
    false
  end

  def year_in_review_enabled?
    Account.current.year_in_review_2017_enabled? && review_available?
  end

  def freshchat_enabled?
    current_account.freshchat_enabled? && current_account.freshchat_account.try(:enabled)
  end

  def freshcaller_enabled_agent?
    # this method mainly for old ui. Need to revisit while removing code files for OLD UI deprecation.
    false
  end

  def sandbox_production_notification
    current_path = request.env['PATH_INFO']
    if (!current_account.sandbox? && SANDBOX_NOTIFICATION_STATUS.include?(current_account.sandbox_job.try(:status)) && SANDBOX_URL_PATHS.select{ |i| current_path.include?(i)}.any?)
      sandbox_url = DomainMapping.find_by_account_id(current_account.sandbox_job.sandbox_account_id).domain
      return content_tag('div', "<span class='sandbox-info'>
            <span class='ficon-notice-o fsize-24 muted'></span>
          </span>
        #{t('sandbox.banner.production_info', :url => sandbox_url)}".html_safe, :class =>
        "sandbox-notification-content")
    end
  end

  def sso_enable_warning_if_freshid_enabled
    if (current_account.freshid_integration_enabled? && current_account.freshconnect_enabled? && !current_account.sso_enabled?)
      return content_tag('div', "<span class='sso-info'>
            <span class='ficon-notice-o fsize-24 muted'></span>
          </span>
        #{t('admin.security.index.freshconnect_warning')}".html_safe, :class =>
        "sso-notification-content")
    end
  end

  def is_sandbox_production_active
    !current_account.sandbox? &&
    SANDBOX_NOTIFICATION_STATUS.include?(current_account.sandbox_job.try(:status)) &&
    SANDBOX_URL_PATHS.select{ |i| request.env['PATH_INFO'].include?(i)}.any?
  end

  def show_sandbox_notification
    !(Account.current.account_type == 2) && !is_sandbox_production_active && Account.current.sandbox_enabled?
  end

  def support_mint_applicable?
    if !current_account.falcon_portal_theme_enabled? && current_account.launched?(:mint_portal_applicable)
      portals = current_account.portals
      portals.any? do |current_portal|
        current_template = current_portal.template
        !current_portal.falcon_portal_enable? && current_template.header.blank? && current_template.footer.blank? &&  current_template.custom_css.blank? && current_template.layout.blank? && current_template.pages.size == 0
      end
    end
  end

  def support_mint_applicable_portal?(current_portal) 
    if !current_account.falcon_portal_theme_enabled? && current_account.launched?(:mint_portal_applicable)    
      current_template = current_portal.template
      !current_portal.falcon_portal_enable? && current_template.header.blank? && current_template.footer.blank? &&  current_template.custom_css.blank? && current_template.layout.blank? && current_template.pages.size == 0
    end
  end

  def mint_preview_key
       if User.current
          MINT_PREVIEW_KEY % { :account_id => current_account.id, 
                       :user_id => User.current.id, :portal_id => current_portal.id}
      end
     end

  def split_with_separator(bucket)
    bucket.present? ? bucket.split('||').map(&:strip) : []
  end
end
