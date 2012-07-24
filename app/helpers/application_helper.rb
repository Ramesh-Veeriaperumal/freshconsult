# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  include SavageBeast::ApplicationHelper
  include Juixe::Acts::Voteable
  include ActionView::Helpers::TextHelper

  require "twitter"
  
  ASSETIMAGE = { :help => "/images/helpimages" }
  
  def format_float_value(val)
    sprintf( "%0.02f", val) unless val.nil? 
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
      "#{days} days and #{hours % 24} hours"
    elsif hours > 0
      "#{hours} hours and #{mins % 60} minutes"
    elsif mins > 0
      "#{mins} minutes and #{secs % 60} seconds"
    elsif secs >= 0
      "#{secs} seconds"
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
    [:notice, :warning, :error].collect {|type| content_tag('div', flash[type], :id => type, :class => "flash_info #{type}") if flash[type] }
  end
  
  def show_admin_flash
    [:notice, :warning, :error].collect {|type| content_tag('div', "<a class='close' data-dismiss='alert'>×</a>" + flash[type], :id => type, :class => "alert alert-block alert-#{type}") if flash[type] }  
  end   

  def show_announcements                                                    
    if permission?(:manage_tickets)
      @current_announcements ||= SubscriptionAnnouncement.current_announcements(session[:announcement_hide_time])  
      render :partial => "/shared/announcement", :object => @current_announcements unless @current_announcements.blank?
    end     
  end         

  def page_title
    portal_name = h( (current_portal.name.blank?) ? current_portal.product.name : current_portal.name ) + " : "
    portal_name += @page_title || t('helpdesk_title')
  end 
  
  def page_description
    @page_description
  end                
  
  def page_keywords
    @page_keywords    
  end

  def tab(title, url, cls = false)
    content_tag('li', content_tag('span') + link_to(strip_tags(title), url), :class => ( cls ? "active": "" ) )
  end
  
  def show_ajax_flash(page)
    page.replace_html :noticeajax, flash[:notice]
    page << "$('noticeajax').show()"
    page << "closeableFlash('#noticeajax')"
    flash.discard
  end

  def each_or_message(partial, collection, message)
    render(:partial => partial, :collection => collection) || content_tag(:div, message, :class => "list-noinfo")
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
        when "link" then
          auto_link(value)
      end
    end
  end

  def navigation_tabs
    tabs = [
      ['/home',               :home,        !permission?(:manage_tickets) ],
      ['helpdesk/dashboard',  :dashboard,    permission?(:manage_tickets)],
      ['helpdesk/tickets',    :tickets,      permission?(:manage_tickets)],
      ['/social/twitters/feed', :social,     can_view_twitter?  ],
      solutions_tab,      
      forums_tab,
      ['/contacts',           :customers,    permission?(:manage_customers)],
      ['support/tickets',     :checkstatus, !permission?(:manage_tickets)],
      ['/reports',            :reports,      permission?(:manage_reports) ],
      ['/admin/home',         :admin,        permission?(:manage_users)],
      company_tickets_tab
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
      tab( s[3] || t("header.tabs.#{s[1].to_s}") , {:controller => s[0], :action => :index}, active && :active ) 
    end
    navigation
  end          

  def subscription_tabs
    tabs = [
      [customers_admin_subscriptions_path, :customers, "Customers" ],
      [admin_subscription_affiliates_path, :affiliates, "Affiliates" ],
      [admin_subscription_discounts_path, :discounts, "Discounts" ],
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
    link_to(link_display, "#{helpdesk_ticket_path args_hash['ticket_id']}#time_entry#{args_hash['timesheet_id']}")
  end
  #Liquid ends here..
  
  #Ticket place-holders, which will be used in email and comment contents.
  def ticket_placeholders #To do.. i18n
    place_holders = [
      ['{{ticket.id}}',           'Ticket ID' ,       'Unique ticket ID.'],
      ['{{ticket.subject}}',          'Subject',          'Ticket subject.'],
      ['{{ticket.description}}',      'Description',        'Ticket description.'],
      ['{{ticket.url}}',          'Ticket URL' ,            'Full URL path to ticket.'],
      ['{{ticket.portal_url}}', 'Product specific ticket URL',  'Full URL path to ticket in product portal. Will be useful in multiple product/brand environments.'],
      ['{{ticket.status}}',         'Status' ,          'Ticket status.'],
      ['{{ticket.priority}}',         'Priority',         'Ticket priority.'],
      ['{{ticket.source}}',         'Source',           'The source channel of the ticket.'],
      ['{{ticket.ticket_type}}',      'Ticket type',        'Ticket type.'],
      ['{{ticket.tags}}',           'Tags',           'Ticket tags.'],
      ['{{ticket.due_by_time}}',      'Due by time',        'Ticket due by time.'],
      ['{{ticket.requester.name}}',     'Requester name',       'Name of the requester who raised the ticket.'],
      ['{{ticket.requester.email}}',    'Requester email',      "Requester's email."],
      ['{{ticket.requester.company_name}}', 'Requester company name',   "Requester's company name."], #??? should it be requester.company.name?!
      ['{{ticket.group.name}}',       'Group name',       'Ticket group.'],
      ['{{ticket.agent.name}}',       'Agent name',       'Name of the agent who is currently working on the ticket.'],
      ['{{ticket.agent.email}}',      'Agent email',        "Agent's email."],
      ['{{ticket.latest_public_comment}}',  'Last public comment',  'Latest public comment for this ticket.'],
      ['{{helpdesk_name}}', 'Helpdesk name', 'Your main helpdesk portal name.'],
      ['{{ticket.portal_name}}', 'Product portal name', 'Product specific portal name in multiple product/brand environments.']      
    ]
    place_holders << ['{{ticket.satisfaction_survey}}', 'Satisfaction survey', 'Includes satisfaction survey.'] if current_account.features?(:surveys, :survey_links)
    place_holders
  end
  
  # Avatar helper for user profile image
  # :medium and :small size of the original image will be saved as an attachment to the user 
  def user_avatar( user, profile_size = :thumb, profile_class = "preview_pic" )
    content_tag( :div, (image_tag (user.avatar) ? user.avatar.content.url(profile_size) : is_user_social(user, profile_size), :onerror => "imgerror(this)", :alt => ""), :class => profile_class, :size_type => profile_size )
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
    "http://api.twitter.com/1/users/profile_image?screen_name=#{screen_name}&size=#{profile_size}"
  end
  
  def facebook_avatar( facebook_id, profile_size = "square")
    "http://graph.facebook.com/#{facebook_id}/picture?type=#{profile_size}"
  end
  
  # User details page link should be shown only to agents and admin
  def link_to_user(user, options = {})
    if current_user && !current_user.customer?
      link_to(user.display_name, user, options)
    else 
      content_tag(:strong, user.display_name, options)
    end
  end
  
  # Date and time format that is mostly used in our product
  def formated_date(date_time, format = "%B %e %Y @ %I:%M %p")
    format = format.gsub(/.\b[%Yy]/, "") if (date_time.year == Time.now.year)
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
 
 def get_time_in_hours seconds
   sprintf( "%0.02f", seconds/3600)
 end
 
 def get_total_time time_sheets
   total_time_in_sec = time_sheets.collect{|t| t.running_time}.sum
   return get_time_in_hours(total_time_in_sec)
 end
  
  def get_app_config(app_name)
    installed_app = get_app_details(app_name)
    return installed_app[0].configs[:inputs] unless installed_app.blank?
  end

  def is_application_installed?(app_name)
    installed_app = get_app_details(app_name)
    return !(installed_app.blank?)
  end

  def get_app_details(app_name)
    installed_app = Integrations::InstalledApplication.find(:all, :joins=>:application, 
                  :conditions => {:applications => {:name => app_name}, :account_id => current_account})
    return installed_app
  end

  def get_app_widget_script(app_name, widget_name, liquid_objs) 
    installed_app = Integrations::InstalledApplication.find(:first, :joins=>{:application => :widgets}, 
                  :conditions => {:applications => {:name => app_name, :widgets => {:name => widget_name}}, :account_id => current_account})
    if installed_app.blank? or installed_app.application.blank?
      return ""
    else
      widget = installed_app.application.widgets[0]
      # replace_objs will contain all the necessary liquid parameter's real values that needs to be replaced.
      replace_objs = {installed_app.application.name.to_s => installed_app, "application" => installed_app.application} # Application name based liquid obj values.
      replace_objs = liquid_objs.blank? ? replace_objs : liquid_objs.merge(replace_objs) # If the there is no liquid_objs passed then just use the application name based values alone.
      return Liquid::Template.parse(widget.script).render(replace_objs, :filters => [Integrations::FDTextFilter])  # replace the liquid objs with real values.
    end
  end

  def construct_ui_element(object_name, field_name, field, field_value = "")
    
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
          choices[i] = t(choice);i=i+1
        end
        element = label + select(object_name, field_name, choices, :class => element_class, :selected => field_value)
      when "custom" then
        rendered_partial = (render :partial => field[:partial])
        element = "#{label} #{rendered_partial}"
      when "hidden" then
        element = hidden_field(object_name , field_name , :value => field_value)
      when "checkbox" then
        element = content_tag(:div, check_box(object_name, field_name, :class => element_class, :checked => field_value ) + field_label)
      when "html_paragraph" then
        element = label + text_area(object_name, field_name, :class => "mceEditor", :value => field_value)
    end
    element
  end

  def construct_ticket_element(object_name, field, field_label, dom_type, required, field_value = "", field_name = "", in_portal = false)
    dom_type = (field.field_type == "nested_field") ? "nested_field" : dom_type
    element_class   = " #{ (required) ? 'required' : '' } #{ dom_type }"
    field_label    += " #{ (required) ? '<span class="required_star">*</span>' : '' }"
    field_name      = (field_name.blank?) ? field.field_name : field_name
    object_name     = "#{object_name.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }"
    label = label_tag object_name+"_"+field.field_name, field_label
    case dom_type
      when "requester" then
        element = label + content_tag(:div, render(:partial => "/shared/autocomplete_email.html", :locals => { :object_name => object_name, :field => field, :url => autocomplete_helpdesk_authorizations_path, :object_name => object_name }))    
        element = add_cc_field_tag element ,field 
      when "email" then
        element = label + text_field(object_name, field_name, :class => element_class, :value => field_value)
        element = add_cc_field_tag element ,field if field.portal_cc_field?
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
    content_tag :li, element, :class => dom_type
  end

  def add_cc_field_tag element , field    
    if current_user && current_user.agent? 
      element  = element + content_tag(:div, render(:partial => "/shared/cc_email_all.html")) 
    elsif current_user && current_user.customer? && field.all_cc_in_portal?
      element  = element + content_tag(:div, render(:partial => "/shared/cc_email_all.html"))
    else
       element  = element + content_tag(:div, render(:partial => "/shared/cc_email.html")) if (current_user && field.company_cc_in_portal? && current_user.customer) 
    end
  end

  # The field_value(init value) for the nested field should be in the the following format
  # { :category_val => "", :subcategory_val => "", :item_val => "" }
  def nested_field_tag(_name, _fieldname, _field, _opt = {}, _htmlopts = {}, _field_values = {}, in_portal = false)        
    _category = select(_name, _fieldname, _field.choices, _opt, _htmlopts)
    _javascript_opts = {
      :data_tree => _field.nested_choices,
      :initValues => _field_values
    }.merge!(_opt)

    _field.nested_levels.each do |l|       
      _javascript_opts[(l[:level] == 2) ? :subcategory_id : :item_id] = sanitize_to_id(_name +"_"+ l[:name])
      _category += content_tag :div, content_tag(:label, l[(!in_portal)? :label : :label_in_portal]) + select(_name, l[:name], [], _opt, _htmlopts), :class => "level_#{l[:level]}"
    end
    
    _category + javascript_tag("jQuery('##{sanitize_to_id(_name +"_"+ _fieldname)}').nested_select_tag(#{_javascript_opts.to_json});")        

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
      field_value = field.dropdown_selected(field.choices, field_value) if(dom_type == "dropdown") || (dom_type == "dropdown_blank")
      element = label + label_tag(field_name, field_value, :class => "value_label")
    end
    
    content_tag :li, element unless display_tag? (element,field,field_value)
  end

  def display_tag? (element, field, field_value)
    (element.blank? || field_value.nil? || field_value == "" || field_value == "..." || ((field.field_type == "custom_checkbox") && !field_value))
  end
   
  def pageless(total_pages, url, message=t("loading.items"), params = {})
    opts = {
      :totalPages => total_pages,
      :url        => url,
      :loaderMsg  => message,
      :params => params
    } 
    javascript_tag("jQuery('#Pages').pageless(#{opts.to_json});")
  end
  
  def render_page
    respond_to do |format|
      format.html { redirect_to :back }
      format.js
    end
  end
   
  private
    def solutions_tab
      if current_portal.main_portal?
        ['solution/categories', :solutions, allowed_in_portal?(:open_solutions)]
      elsif current_portal.solution_category
        [solution_category_path(current_portal.solution_category), :solutions, 
              allowed_in_portal?(:open_solutions)]
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
    
    def forums_visibility?
      feature?(:forums) && allowed_in_portal?(:open_forums)
    end
    
    def can_view_twitter?
      permission?(:manage_tickets) && !current_account.twitter_handles.blank? && feature?(:twitter)
    end
    
  
  def company_tickets_tab
    tab = ['support/company_tickets', :company_tickets , !permission?(:manage_tickets) , current_user.customer.name] if (current_user && current_user.customer && current_user.client_manager?)
    tab || ""
  end
  
end
