# encoding: utf-8
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  include SavageBeast::ApplicationHelper
  include Juixe::Acts::Voteable
  include ActionView::Helpers::TextHelper
  include Gamification::GamificationUtil

  include MemcacheKeys

  require "twitter"
  
  ASSETIMAGE = { :help => "/images/helpimages" }

  def open_html_tag
    html_conditions = [ ["lt IE 7", "ie6"],
                        ["IE 7", "ie7"],
                        ["IE 8", "ie8"],
                        ["IE 9", "ie9"],
                        ["IE 10", "ie10"],
                        ["(gt IE 10)|!(IE)", "", true]]

    html_conditions.map { |h| %( 
        <!--[if #{h[0]}]>#{h[2] ? '<!-->' : ''}<html class="no-js #{h[1]}" lang="#{ 
          current_portal.language }">#{h[2] ? '<!--' : ''}<![endif]--> ) }
  end
  
  def format_float_value(val)
    if !(val.is_a? Fixnum)
      sprintf( "%0.01f", val)
    else
      return val.to_s
    end
  end

  def logo_url
    MemcacheKeys.fetch(["v4","portal","logo",current_portal],30.days.to_i) do
      image_tag(
        current_portal.logo.nil? ? "/images/logo.png?721013" : 
        AwsWrapper::S3Object.url_for(current_portal.logo.content.path(:logo),current_portal.logo.content.bucket_name,
                                          :expires_in => 30.days, :secure => true)
      )
    end
  end

  def fav_icon_url
    MemcacheKeys.fetch(["v5","portal","fav_ico",current_portal]) do
      url = current_portal.fav_icon.nil? ? '/images/favicon.ico?123456' : 
            AwsWrapper::S3Object.url_for(current_portal.fav_icon.content.path,current_portal.fav_icon.content.bucket_name,
                                          :expires_in => 30.days, :secure => true)
      "<link rel=\"shortcut icon\" href=\"#{url}\" />"
    end
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
      "-"
    elsif days > 0
      "#{days} days  #{hours % 24} hrs"
    elsif hours > 0
      "#{hours} hrs  #{mins % 60} mins"
    elsif mins > 0
      "#{mins} mins  #{secs % 60} secs"
    elsif secs >= 0
      "#{secs} secs"
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
    @show_flash = [:notice, :warning, :error].collect {|type| content_tag('div', flash[type], :id => type, :class => "flash_info #{type}") if flash[type] }
  end
  
  def show_admin_flash
    [:notice, :warning, :error].collect {|type| content_tag('div', "<a class='close' data-dismiss='alert'>×</a>" + flash[type], :id => type, :class => "alert alert-block alert-#{type}") if flash[type] }  
  end   

  def show_announcements                                                    
    if privilege?(:manage_tickets)
      @current_announcements ||= SubscriptionAnnouncement.current_announcements(session[:announcement_hide_time])  
      render :partial => "/shared/announcement", :object => @current_announcements unless @current_announcements.blank?
    end     
  end

  def page_title    
    portal_name = " : #{h(current_portal.portal_name)}" if current_portal.portal_name.present?
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
    options = {:"data-pjax" => "#body-container"}
    if tab_name.eql?(:tickets)
      options.merge!({:"data-parallel-url" => "/helpdesk/tickets/filter_options", :"data-parallel-placeholder" => "#ticket-leftFilter"})
    end
    content_tag('li', content_tag('span') + link_to(strip_tags(title), url, options ), :class => ( cls ? "active": "" ), :"data-tab-name" => tab_name )
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

  

  def each_or_message(partial, collection, message, locals = {})
    render(:partial => partial, :collection => collection, :locals => locals) || content_tag(:div, message, :class => "list-noinfo")
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
    link_to "<strong> #{ button_text } </strong><span></span>", toggle_url, { :class => 
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
          auto_link("http://facebook.com/#{value}")
        when "twitter" then
          value = value.gsub('@','')
          link_to("@#{value}" , "http://twitter.com/#{value}")
        when "link" then
          auto_link(value)
      end
    end
  end

  def fd_menu_link(text, url, is_active)
    text << "<span class='icon ticksymbol'></span>" if is_active
    class_name = is_active ? "active" : ""
    link_to(text, url, :class => class_name, :tabindex => "-1")
  end

  def dropdown_menu(list, options = {})
    return if list.blank?
    output = ""
    output << %(<ul class="dropdown-menu" role="menu" aria-labelledby="dropdownMenu">)
    
    list.each do |item|
      unless item.blank?
        if item[0] == :divider
          output << %(<li class="divider"></li>)
        else
          output << %(<li class="#{item[2] ? "active" : ""}">#{ link_to item[0], item[1], options, "tabindex" => "-1" }</li>)
        end
      end
    end
    output << %(</ul>)
    output.html_safe
  end

  def dropdown_menu(list, options = {})
    return if list.blank?
    output = ""
    output << %(<ul class="dropdown-menu" role="menu" aria-labelledby="dropdownMenu">)
    
    list.each do |item|
      unless item.blank?
        if item[0] == :divider
          output << %(<li class="divider"></li>)
        else
          output << %(<li class="#{item[2] ? "active" : ""}">#{ link_to item[0], item[1], options, "tabindex" => "-1" }</li>)
        end
      end
    end
    output << %(</ul>)
    output.html_safe
  end

  def navigation_tabs
    tabs = [
      ['/home',               :home,        !privilege?(:manage_tickets) ],
      ['/helpdesk/dashboard',  :dashboard,    privilege?(:manage_tickets)],
      ['/helpdesk/tickets',    :tickets,      privilege?(:manage_tickets)],
      ['/social/twitters/feed', :social,     can_view_twitter?  ],
      solutions_tab,      
      forums_tab,
      ['/contacts',           :customers,    privilege?(:view_contacts)],
      ['/support/tickets',     :checkstatus, !privilege?(:manage_tickets)],
      ['/reports',            :reports,      privilege?(:view_reports) ],
      ['/admin/home',         :admin,        privilege?(:view_admin)],
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
      tab( s[3] || t("header.tabs.#{s[1].to_s}") , {:controller => s[0], :action => :index}, active && :active, s[1] ) 
    end
    navigation
  end          

  def subscription_tabs
    tabs = [
      [customers_admin_subscriptions_path, :customers, "Customers" ],
      [admin_subscription_affiliates_path, :affiliates, "Affiliates" ],
      [admin_subscription_payments_path, :payments, "Payments" ],
      [admin_subscription_announcements_path, :announcements, "Announcements" ]
    ]

    navigation = tabs.map do |s| 
      content_tag(:li, link_to(s[2], s[0]), :class => ((@selected_tab == s[1]) ? "active" : ""))
    end
  end

  def show_contact_hovercard(user, options=nil)
    if privilege?(:view_contacts)
      link_to(h(user), user, :class => "username", "data-placement" => "topRight", :rel => "contact-hover", "data-contact-id" => user.id, "data-contact-url" => hover_card_contact_path(user)) unless user.blank?
    else
      link_to(h(user), "javascript:void(0)", :class => "username") unless user.blank?
    end
  end
  
  def html_list(type, elements, options = {}, activeitem = 0)
    if elements.empty?
      "" 
    else
      lis = elements.map { |x| content_tag("li", x, :class => ("active first" if (elements[activeitem] == x)))  }
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
    unless data['eval_args'].nil?
      data['eval_args'].each_pair do |k, v|
        data[k] = send(v[0].to_sym, v[1])
      end
    end
    
    data
  end
   
  def responder_path(args_hash)
    link_to(h(args_hash['name']), user_path(args_hash['id']))
  end
  
  def comment_path(args_hash, link_display = 'note')
    link_to(link_display, "#{helpdesk_ticket_path args_hash['ticket_id']}#note#{args_hash['comment_id']}")
  end
  
  def email_response_path(args_hash)
    comment_path(args_hash, 'email response')
  end
  
  def reply_path(args_hash)
    comment_path(args_hash, 'reply')
  end
  
  def fwd_path(args_hash)
    comment_path(args_hash, 'forwarded')
  end
  
  def twitter_path(args_hash)
    comment_path(args_hash, 'tweet')
  end
  
  def merge_ticket_path(args_hash)    
    link_to(args_hash['subject']+"(##{args_hash['ticket_id']})", "#{helpdesk_ticket_path args_hash['ticket_id']}}")
  end
  
  def split_ticket_path(args_hash)
    link_to(args_hash['subject']+"(##{args_hash['ticket_id']})", "#{helpdesk_ticket_path args_hash['ticket_id']}}")
  end
  
   def timesheet_path(args_hash, link_display = 'time entry')
    link_to(link_display, "#{helpdesk_ticket_path args_hash['ticket_id']}#timeentry_#{args_hash['timesheet_id']}")
  end
  #Liquid ends here..
  
  #Ticket place-holders, which will be used in email and comment contents.
  def ticket_placeholders #To do.. i18n
    place_holders = [
      ['{{ticket.id}}',           'Ticket ID' ,       'Unique ticket ID.'],
      ['{{ticket.subject}}',          'Subject',          'Ticket subject.'],
      ['{{ticket.description}}',      'Description',        'Ticket description.'],
      ['{{ticket.url}}',          'Ticket URL' ,            'Full URL path to ticket.'],
      ['{{ticket.public_url}}',          'Public Ticket URL' ,            'URL for accessing the tickets without login'],
      ['{{ticket.portal_url}}', 'Product specific ticket URL',  'Full URL path to ticket in product portal. Will be useful in multiple product/brand environments.'],
      ['{{ticket.status}}',         'Status' ,          'Ticket status.'],
      ['{{ticket.priority}}',         'Priority',         'Ticket priority.'],
      ['{{ticket.source}}',         'Source',           'The source channel of the ticket.'],
      ['{{ticket.ticket_type}}',      'Ticket type',        'Ticket type.'],
      ['{{ticket.tags}}',           'Tags',           'Ticket tags.'],
      ['{{ticket.due_by_time}}',      'Due by time',        'Ticket due by time.'],
      ['{{ticket.requester.name}}',     'Requester name',       'Name of the requester who raised the ticket.'],
      ['{{ticket.requester.firstname}}' , 'Requester first name', 'First name of the requester who raised the ticket'],
      ['{{ticket.requester.lastname}}' , 'Requester last name', 'Last name of the requester who raised the ticket'],
      ['{{ticket.requester.email}}',    'Requester email',      "Requester's email."],
      ['{{ticket.requester.company_name}}', 'Requester company name',   "Requester's company name."], #??? should it be requester.company.name?!
      ['{{ticket.requester.phone}}', 'Requester phone number',   "Requester's phone number."],
      ['{{ticket.group.name}}',       'Group name',       'Ticket group.'],
      ['{{ticket.agent.name}}',       'Agent name',       'Name of the agent who is currently working on the ticket.'],
      ['{{ticket.agent.email}}',      'Agent email',        "Agent's email."],
      ['{{ticket.latest_public_comment}}',  'Last public comment',  'Latest public comment for this ticket.'],
      ['{{helpdesk_name}}', 'Helpdesk name', 'Your main helpdesk portal name.'],
      ['{{ticket.portal_name}}', 'Product portal name', 'Product specific portal name in multiple product/brand environments.'],
      ['{{ticket.product_description}}', 'Product description', 'Product specific description in multiple product/brand environments.']
    ]
    place_holders << ['{{ticket.satisfaction_survey}}', 'Satisfaction survey', 'Includes satisfaction survey.'] if current_account.features?(:surveys, :survey_links)
    current_account.ticket_fields.custom_fields.each { |custom_field|
      name = custom_field.name[0..custom_field.name.rindex('_')-1]
      place_holders << ["{{ticket.#{name}}}", custom_field.label, "#{custom_field.label} (Custom Field)"] unless name == "type"
    }
    place_holders
  end
  
  # Avatar helper for user profile image
  # :medium and :small size of the original image will be saved as an attachment to the user 
  def user_avatar( user, profile_size = :thumb, profile_class = "preview_pic" ,options = {})
    img_tag_options = { :onerror => "imgerror(this)", :alt => "" }
    if options.include?(:width)  
      img_tag_options[:width] = options.fetch(:width)
      img_tag_options[:height] = options.fetch(:height)
    end 
    avatar_content = MemcacheKeys.fetch(["v4","avatar",profile_size,user],30.days.to_i) do
      content_tag( :div, (image_tag (user.avatar) ? user.avatar.expiring_url(profile_size,30.days.to_i) : is_user_social(user, profile_size), img_tag_options ), :class => profile_class, :size_type => profile_size )
    end
    avatar_content
  end

  def user_avatar_with_expiry( user, expiry = 300)
    user_avatar(user,:thumb,"preview_pic",{:expiry => expiry, :width => 36, :height => 36})
  end
  
  def is_user_social( user, profile_size )
    if user.twitter_id
      profile_size = (profile_size == :medium) ? "original" : "normal"
      twitter_avatar(user.twitter_id, profile_size) 
    elsif user.fb_profile_id
      profile_size = (profile_size == :medium) ? "large" : "square"
      facebook_avatar(user.fb_profile_id, profile_size)
    else
      "/images/fillers/profile_blank_#{profile_size}.gif"
    end
  end   
  
  def twitter_avatar( screen_name, profile_size = "normal" )
    "https://api.twitter.com/1/users/profile_image?screen_name=#{screen_name}&size=#{profile_size}"
  end
  
  def facebook_avatar( facebook_id, profile_size = "square")
    "https://graph.facebook.com/#{facebook_id}/picture?type=#{profile_size}"
  end
  
  # User details page link should be shown only to agents and admin
  def link_to_user(user, options = {})
    if privilege?(:view_contacts)
      link_to(h(user.display_name), user, options)
    else 
      content_tag(:strong, h(user.display_name), options)
    end
  end
  
  # Date and time format that is mostly used in our product
  def formated_date(date_time, format = "%a, %b %e, %Y at %l:%M %p")
    format = format.gsub(/,\s.\b[%Yy]\b/, "") if (date_time.year == Time.now.year)
    date_time.strftime(format)
  end
  
  # Get Pref color for individual portal
  def portal_pref(item, type)
   color = current_account.main_portal[:preferences].fetch(type, '')
   if !item[:preferences].blank?
     color = item[:preferences].fetch(type, '')
   end
   color
 end
 
 # def get_time_in_hours seconds
 #   sprintf( "%0.02f", seconds/3600)
 # end
 
 def get_time_in_hours seconds
  hh = (seconds/3600).to_i
  mm = ((seconds % 3600) / 60).to_i

  hh.to_s.rjust(2,'0') + ":" + mm.to_s.rjust(2,'0')
 end
 
 def get_total_time time_sheets
   total_time_in_sec = time_sheets.collect{|t| t.running_time}.sum
   return get_time_in_hours(total_time_in_sec)
 end
  
  def get_app_config(app_name)
    installed_app = get_app_details(app_name)
    return installed_app.configs[:inputs] unless installed_app.blank?
  end

  def is_application_installed?(app_name)
    installed_app = get_app_details(app_name)
    return !(installed_app.blank?)
  end

  def get_app_details(app_name)
    installed_app = installed_apps[app_name.to_sym]
    return installed_app
  end

  #This one checks for installed apps in account
  def dropbox_app_key
    app = installed_apps[:dropbox]
    app.configs[:inputs]['app_key']  unless (app.blank?)
  end

  def installed_apps 
    @installed_apps ||= current_account.installed_apps_hash
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
    replace_objs = replace_objs.merge({installed_app.application.name.to_s => installed_app, 'installed_app' => (InstalledAppDrop.new installed_app), "application" => installed_app.application, 'portal_id' => current_portal.id}) unless installed_app.blank?# Application name based liquid obj values.
    Liquid::Template.parse(widget.script).render(replace_objs, :filters => [Integrations::FDTextFilter])  # replace the liquid objs with real values.
  end

  def construct_ui_element(object_name, field_name, field, field_value = "", installed_app=nil, form=nil)
    field_label = t(field[:label])
    dom_type = field[:type]
    required = field[:required]
    rel_value = field[:rel]
    url_autofill_validator = field[:validator_type]
    ghost_value = field[:autofill_text]
    encryption_type = field[:encryption_type]
    element_class   = " #{ (required) ? 'required' : '' }  #{ (url_autofill_validator) ? url_autofill_validator  : '' } #{ dom_type }"
    field_label    += " #{ (required) ? '*' : '' }"
    object_name     = "#{object_name.to_s}"
    label = label_tag object_name+"_"+field_name, field_label
    dom_type = dom_type.to_s

    case dom_type
      when "text", "number", "email", "multiemail" then
        field_value = field_value.to_s.split(ghost_value).first unless ghost_value.blank?
        element = label + text_field(object_name, field_name, :class => element_class, :value => field_value, :rel => rel_value, "data-ghost-text" => ghost_value)
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
        element = label + select(object_name, field_name, choices, :class => element_class, :selected => field_value)
      when "custom" then
        rendered_partial = (render :partial => field[:partial], :locals => {:installed_app=>installed_app, :f=>form})
        element = "#{label} #{rendered_partial}"
      when "hidden" then
        element = hidden_field(object_name , field_name , :value => field_value)
      when "checkbox" then
        element = content_tag(:div, check_box(object_name, field_name, :class => element_class, :checked => field_value ) + field_label)
      when "html_paragraph" then
        element = label + text_area(object_name, field_name, :value => field_value)
    end
    element
  end

  def construct_ticket_element(form_builder,object_name, field, field_label, dom_type, required, field_value = "", field_name = "", in_portal = false , is_edit = false)
    dom_type = (field.field_type == "nested_field") ? "nested_field" : dom_type
    element_class   = " #{ (required) ? 'required' : '' } #{ dom_type }"
    element_class  += " required_closure" if (field.required_for_closure && !field.required)
    field_label    += '<span class="required_star">*</span>' if required
    field_label    += "#{add_requester_field}" if (dom_type == "requester" && !is_edit) #add_requester_field has been type converted to string to handle false conditions
    field_name      = (field_name.blank?) ? field.field_name : field_name
    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }"
    label = label_tag object_name+"_"+field.field_name, field_label
    choices = field.choices
    case dom_type
      when "requester" then
        element = label + content_tag(:div, render(:partial => "/shared/autocomplete_email.html", :locals => { :object_name => object_name, :field => field, :url => requester_autocomplete_helpdesk_authorizations_path, :object_name => object_name }))  
        element+= hidden_field(object_name, :requester_id, :value => @item.requester_id)
        unless is_edit or params[:format] == 'widget'
          element = add_cc_field_tag element, field  
        end
      when "email" then
        element = label + text_field(object_name, field_name, :class => element_class, :value => field_value)
        element = add_cc_field_tag element ,field if (field.portal_cc_field? && !is_edit && controller_name.singularize != "feedback_widget") #dirty fix
        element += add_name_field if !is_edit and !current_user
      when "text", "number" then
        element = label + text_field(object_name, field_name, :class => element_class, :value => field_value)
      when "paragraph" then
        element = label + text_area(object_name, field_name, :class => element_class, :value => field_value)
      when "dropdown" then
        if (['default_priority','default_source','default_status'].include?(field.field_type) )
          element = label + select(object_name, field_name, field.html_unescaped_choices, {:selected => field_value},{:class => element_class}) 
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
        element = label + nested_field_tag(object_name, field_name, field, {:include_blank => "...", :selected => field_value}, {:class => element_class}, field_value, in_portal)
      when "hidden" then
        element = hidden_field(object_name , field_name , :value => field_value)
      when "checkbox" then
        element = content_tag(:div, (check_box(object_name, field_name, :class => element_class, :checked => field_value ) + label))
      when "html_paragraph" then
        form_builder.fields_for(:ticket_body, @ticket.ticket_body ) do |builder|
            element = label + builder.text_area(field_name, :class => element_class, :value => field_value )
        end
    end
    content_tag :li, element, :class => " #{ dom_type } #{ field.field_type } field"
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
    render(:partial => "/shared/add_requester") if (params[:format] != 'widget' && privilege?(:manage_contacts))
  end
  
  def add_name_field
    content_tag(:li, (content_tag(:div, render(:partial => "/shared/name_field"))).to_s,
                :id => "name_field", :class => "hide") unless current_user
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
    
    _category + javascript_tag("jQuery('##{(_name +"_"+ _fieldname).gsub('[','_').gsub(']','')}').nested_select_tag(#{_javascript_opts.to_json});")

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
   
  def pageless(total_pages, url, message=t("loading.items"), params = {})
    opts = {
      :totalPages => total_pages,
      :url        => url,
      :loaderMsg  => message,
      :params => params,
      :currentPage => 1
    } 
    javascript_tag("jQuery('#Pages').pageless(#{opts.to_json});")
  end
  
  def render_page
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end

  def email_regex
    Helpdesk::Ticket::VALID_EMAIL_REGEX.source
  end

  def nodejs_url namespace
    nodejs_port = Rails.env.development? ? 5000 : (request.ssl? ? 2050 : 1050)      
    "#{request.protocol}#{request.host}:#{nodejs_port}/#{namespace}"
  end  

  def es_enabled?
    current_account.es_enabled?
  end
  
  def truncate_filename filename
    extension = filename.include?('.') ? filename.split('.').last : nil
    extension = nil if filename.gsub('.','') == extension
    simple_name = extension ? filename[0..-(extension.to_s.length + 2)] : filename
    if filename.length > 20
      return simple_name[0,15] + "..." + simple_name[-2..-1] + (extension ? ".#{extension}" : "")
    end
    filename
  end

  def assumed_identity_message
    _output = []
    if current_user && is_assumed_user?
      _output << %( <div class="alert alert-assume-agent alert-solid"> )
      _output << %( #{t('header.assumed_text')} <b> #{current_user.name}</b> - )
      _output << link_to(t('revert_identity_link_msg'), revert_identity_users_path, :class => "link")
      _output << %( </div> )
    end
    _output.join("")
  end

  def get_logo
    unless @account.main_portal.logo.blank?
      return @account.main_portal.logo.content.url(:logo)
    end
    return "/images/logo.png?721013"
  end
   
  private
    def solutions_tab
      if current_portal.main_portal?
        ['/solution/categories', :solutions, solutions_visibility?]
      elsif current_portal.solution_category
        [solution_category_path(current_portal.solution_category), :solutions, 
              solutions_visibility?]
      else
        ['#', :solutions, false]
      end
    end
    
    def forums_tab
      if main_portal?
        ['/categories', :forums,  forums_visibility?]
      elsif current_portal.forum_category
        [category_path(current_portal.forum_category), :forums,  forums_visibility?]
      else
        ['#', :forums, false]
      end
    end
    
    def solutions_visibility?
      allowed_in_portal?(:open_solutions) && privilege?(:view_solutions)
    end

    def forums_visibility?
      feature?(:forums) && allowed_in_portal?(:open_forums) && privilege?(:view_forums)
    end
    
    def can_view_twitter?
      privilege?(:manage_tickets) && !current_account.twitter_handles.blank? && feature?(:twitter)
    end
    
  def tour_button(text, tour_id)
    link_to(text, '#', :rel => 'guided-tour', "data-tour-id" => tour_id, :class=> 'guided-tour-button')
  end
  
  def check_fb_reauth_required
    fb_page = current_account.fb_reauth_check_from_cache
    if fb_page
      return content_tag('div', "<a href='javascript:void(0)'></a>  Your Facebook channel is inaccessible. 
        It looks like username, password, or permission has been changed recently.Kindly 
        <a href='/social/facebook' target='_blank'> fix </a> it.  ", :class => 
        "alert-message block-message warning full-width")
    end
    return
  end
 
  def check_twitter_reauth_required
    twt_handle= current_account.twitter_reauth_check_from_cache
    if twt_handle
      return content_tag('div', "<a href='javascript:void(0)'></a>  Your Twitter channel is inaccessible. 
        It looks like username or password has been changed recently. Kindly 
        <a href='/social/twitters' target='_blank'> fix </a> it.  ", :class => 
        "alert-message block-message warning full-width")
    end
    return
  end
  
  # This helper is for the partial expanded/_ticket.html.erb
  def requester(ticket)
    if privilege?(:view_contacts)
      "<a class = 'user_name' href='/users/#{ticket.requester.id}'><span class='emphasize'>#{h(ticket.requester.display_name)}</span></a>"
    else
      "<span class = 'user_name emphasize'>#{h(ticket.requester.display_name)}</span>"
    end
  end
  
  # This helper is for the partial expanded/_ticket.html.erb
  def quick_action
    privilege?(:edit_ticket_properties) ? 'quick-action dynamic-menu' : ''
  end
  
  def note_responder(note)
    if privilege?(:view_contacts)
      link_to_user(note.user, :class => "user_name", "data-placement" => "topRight",
        :rel => "hover-popover", "data-widget-container" => "agent-hovercard_#{note.id}" )
    else
      link_to_user(note.user, :class => "user_name", "data-placement" => "topRight")
    end
  end
  
end
