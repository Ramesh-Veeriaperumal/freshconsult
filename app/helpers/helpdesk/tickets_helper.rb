module Helpdesk::TicketsHelper
  
  include Wf::HelperMethods
  include TicketsFilter
  include Helpdesk::Ticketfields::TicketStatus
  include Helpdesk::NoteActions
  include RedisKeys
  include Integrations::AppsUtil

  def view_menu_links( view, cls = "", selected = false )
    unless(view[:id] == -1)
      link_to( (content_tag(:span, "", :class => "icon ticksymbol") if selected).to_s + strip_tags(view[:name]), (view[:default] ? helpdesk_filter_view_default_path(view[:id]) : helpdesk_filter_view_custom_path(view[:id])) , :class => ( selected ? "active #{cls}": "#{cls}"), :rel => (view[:default] ? "default_filter" : "" ))
    else
      content_tag(:span, "", :class => "seperator")
    end  
  end
  
  def drop_down_views(viewlist, selected_item, menuid = "leftViewMenu", unsaved_view=false)
    extra_class = ""
    extra_class = "unsaved" if unsaved_view
    unless viewlist.empty?
      more_menu_drop = 
        content_tag(:div, (link_to strip_tags(selected_item), "/helpdesk/tickets", { :class => "drop-right nav-trigger #{extra_class}", :menuid => "##{menuid}", :id => "active_filter" } ), :class => "link-item" ) +
        content_tag(:div, viewlist.map { |s| view_menu_links(s, "", (s[:name].to_s == selected_item.to_s)) }, :class => "fd-menu", :id => menuid)
    end
  end
  
  def ticket_sidebar
    tabs = [["TicketProperties", t('ticket.properties'),         "ticket"],
            ["RelatedSolutions", t('ticket.suggest_solutions'),  "related_solutions"],
            ["Scenario",         t('ticket.execute_scenario'),   "scenarios",       feature?(:scenario_automations)],
            ["RequesterInfo",    t('ticket.requestor_info'),     "requesterinfo"],
            ["Reminder",         t('to_do'),                     "todo"],
            ["Tags",             t('tag.title'),                 "tags"],
            ["Activity",         t('ticket.activities'),         "activity"]]
        
    icons = ul tabs.map{ |t| 
                next if !t[3].nil? && !t[3]
                  link_to content_tag(:span, "", :class => t[2]) + 
                          content_tag(:em, t[1]), "#"+t[0], 
                                "data-remote-load" => ( url_for({ :action => "component", 
                                                                :component => t[2], 
                                                                :id => @ticket.id }) unless (tabs.first == t) )
               }, { :class => "rtPanel", "data-tabs" => "tabs" }
               
    panels = content_tag :div, tabs.map{ |t| 
      if(tabs.first == t)
        content_tag :div, (render :partial => "helpdesk/tickets/components/ticket", :object => @ticket), :class => "rtDetails tab-pane active #{t[2]}", :id => t[0]
      else
        content_tag :div, content_tag(:div, "", :class => "loading-box"), :class => "rtDetails tab-pane #{t[2]}", :id => t[0]
      end
    }, :class => "tab-content"
               
    icons + panels
  end
    
  def ticket_tabs
    tabs = [['Pages',     t(".conversation"), @ticket.conversation_count],
            ['Timesheet', t(".timesheet"),    @ticket.time_sheets.size, 
                                               helpdesk_ticket_helpdesk_time_sheets_path(@ticket), 
                                               feature?(:timesheets)]]
    
    ul tabs.map{ |t| 
                  next if !t[4].nil? && !t[4]
                  link_to t[1] + (content_tag :span, t[2], :class => "pill #{ t[2] == 0 ? 'hide' : ''}", :id => "#{t[0]}Count"), "##{t[0]}", "data-remote-load" => t[3], :id => "#{t[0]}Tab"
                }, { :class => "tabs", "data-tabs" => "tabs" }
                
  end
  
  def top_views(selected = "new_my_open", dynamic_view = [], show_max = 1)
    unless dynamic_view.empty?
      dynamic_view.concat([{ :id => -1 }])
    end
    
    top_views_array = [ 
    ].concat(dynamic_view).concat([
      { :id => "new_my_open",  :name => t("helpdesk.tickets.views.new_my_open"),     :default => true },
      { :id => "all_tickets",  :name => t("helpdesk.tickets.views.all_tickets"),     :default => true },      
      { :id => "monitored_by", :name => t("helpdesk.tickets.views.monitored_by"),    :default => true },
      { :id => "spam"   ,      :name => t("helpdesk.tickets.views.spam"),            :default => true },
      { :id => "deleted",      :name => t("helpdesk.tickets.views.deleted"),         :default => true }
    ])
    top_index = top_views_array.index{|v| v[:id] == selected} || 0

    cannot_delete = false
    selected_item =  top_views_array.select { |v| v[:id].to_s == selected.to_s }.first
    unless selected_item.blank?
      selected_item_name = selected_item[:name]
    else
      selected_item_name = ((SELECTORS.select { |v| v.first == selected.to_sym }.first)[1] || top_views_array.first[:name]).to_s unless selected.blank?
      selected_item_name = t("tickets_filter.unsaved_view") if selected.blank?
      cannot_delete = true
    end

    top_view_html = drop_down_views(top_views_array, selected_item_name, "leftViewMenu", selected.blank? ).to_s +
      (content_tag :div, (link_to t('delete'), {:controller => "wf/filter", :action => "delete_filter", :id => selected_item[:id]}, {:method => :delete, :confirm => t("wf.filter.view.delete"), :id => 'delete_filter'}), :id => "view_manage_links"  unless cannot_delete or selected_item[:default] )
  end
  
  def filter_select( prompt = t('helpdesk.tickets.views.select'))    
    selector = select("select_view", "id", SELECTORS.collect { |v| [v[1], helpdesk_filter_tickets_path(filter(v[0]))] },
              {:prompt => prompt}, { :class => "customSelect" })        
  end

  def filter(selector = nil)
    selector ||= current_selector
  end
  
  def filter_count(selector=nil)
    TicketsFilter.filter(filter(selector), current_user, current_account.tickets.permissible(current_user)).count
  end
  
  def sort_by_text(sort_key, order)
    help_text = [
      [ :due_by     ,   'Showing Latest Due by time'  ],
      [ :created_at ,   'Showing Tickets Date Created' ],
      [ :updated_at ,   'Showing Tickets Last Modified'],
      [ :priority   ,   'Priority',    ],
      [ :status,        'Status',      ],
    ]
  end
  

  def current_filter
    stored_key = params[:filter_key] || params[:filter_name]
    cookies[:filter_name] = (stored_key ? stored_key : (!cookies[:filter_name].blank?) ? cookies[:filter_name] : "new_my_open" )
  end
   
  def current_sort
    cookies[:sort] = (params[:sort] ? params[:sort] : ( (!cookies[:sort].blank?) ? cookies[:sort] : DEFAULT_SORT )).to_sym 
  end
 
  def current_sort_order 
    cookies[:sort_order] = (params[:sort_order] ? params[:sort_order] : ( (!cookies[:sort_order].blank?) ? cookies[:sort_order] : DEFAULT_SORT_ORDER )).to_sym
  end
  
  def current_wf_order
    return @cached_filter_data[:wf_order].to_sym if @cached_filter_data && !@cached_filter_data[:wf_order].blank?
    cookies[:wf_order] = (params[:wf_order] ? params[:wf_order] : ( (!cookies[:wf_order].blank?) ? cookies[:wf_order] : DEFAULT_SORT )).to_sym
  end

  def current_wf_order_type 
    return @cached_filter_data[:wf_order_type] if @cached_filter_data && !@cached_filter_data[:wf_order_type].blank?
    cookies[:wf_order_type] = (params[:wf_order_type] ? params[:wf_order_type] : ( (!cookies[:wf_order_type].blank?) ? cookies[:wf_order_type] : DEFAULT_SORT_ORDER )).to_sym
  end

  def cookie_sort 
     "#{current_sort} #{current_sort_order}"
  end
 
  def current_selector
    current_filter#.reject { |f| CONTEXTS.include? f }
  end

  def filter_title(selector)
    SELECTOR_NAMES[selector]
  end

  def current_filter_title
    filter_title(current_selector)
  end

  def current_selector_name
    SELECTOR_NAMES[current_selector]
  end

  def context_check_box(text, checked_context, unchecked_context, selector = nil)

    checked_url = url_for(:filters => [checked_context] + (selector || current_selector))
    unchecked_url = url_for(:filters => [unchecked_context] + (selector || current_selector))

    check_box_tag(
      "#{checked_context.to_s}_#{unchecked_context.to_s}",
      1, 
      current_context == [checked_context],
      :onclick => "window.location = this.checked ? '#{checked_url}' : '#{unchecked_url}'"
    ) + content_tag(:label, text)
  end

  def search_fields
    select_tag(
      :f, 
      options_for_select(Helpdesk::Ticket::SEARCH_FIELD_OPTIONS, (params[:f] && params[:f].to_sym)), 
      :id => 'ticket-search-field')
  end

  def search_value
    o = []

    html = {:style => "display:none", :disabled => true, :class => 'search-field'} 

    o << text_field_tag(
      :v, 
      params[:v], 
      :id => 'search-default', 
      :class => 'search-field')

    o << select_tag(
      'search-source', 
      options_for_select(Helpdesk::Ticket::SOURCE_OPTIONS, params[:v].to_i), 
      html)

    o << select_tag(
      'search-urgent', 
      options_for_select({"High" => 1, "Normal" => 0}, params[:v].to_i), 
      html)

    o.join
  end
  
  def subject_style(ticket)
    type = "customer_responded" if ticket.ticket_states.customer_responded? && ticket.active?
    type = "new" if ticket.ticket_states.is_new? && !ticket.onhold_and_closed?
    type = "elapsed" if ticket.ticket_states.agent_responded_at.blank? && ticket.frDueBy < Time.now && ticket.due_by >= Time.now && ticket.active?
    type = "overdue" if !ticket.onhold_and_closed? && ticket.due_by < Time.now && ticket.active? 
    type
  end

  def sla_status(ticket)
    if( ticket.active? )
      unless (ticket.onhold_and_closed? or ticket.ticket_status.deleted?)
        if(Time.now > ticket.due_by )
          t('already_overdue',:time_words => distance_of_time_in_words(Time.now, ticket.due_by))
        else
          t('due_in',:time_words => distance_of_time_in_words(Time.now, ticket.due_by))
        end
      else
        " #{h(status_changed_time_value_hash(ticket)[:title])} #{t('for')} 
            #{distance_of_time_in_words(Time.now, ticket.ticket_states.send(status_changed_time_value_hash(ticket)[:method]))} "
      end

    else
      if( ticket.ticket_states.resolved_at < ticket.due_by )
        t('resolved_on_time')
      else
        t('resolved_late')
      end
    end
  end
  
  def bind_last_conv (item, signature, forward = false)
    ticket = (item.is_a? Helpdesk::Ticket) ? item : item.notable
    last_conv = (item.is_a? Helpdesk::Note) ? item : 
                ((!forward && ticket.notes.visible.public.last) ? ticket.notes.visible.public.last : item)
    if (last_conv.is_a? Helpdesk::Ticket)
      last_reply_by = (last_conv.requester.name || '')+"&lt;"+(last_conv.requester.email || '')+"&gt;"
      last_reply_time = last_conv.created_at
      last_reply_content = last_conv.description_html
    else
      last_reply_by = (last_conv.user.name || '')+"&lt;"+(last_conv.user.email || '')+"&gt;" 
      last_reply_by  = (ticket.reply_name || '')+"&lt;"+(ticket.reply_email || '')+"&gt;" unless last_conv.user.customer?       
      last_reply_time = last_conv.created_at
      last_reply_content = last_conv.body_html
      unless last_reply_content.blank?
        doc = Nokogiri::HTML(last_reply_content)
        doc_fd_css = doc.css('div.freshdesk_quote')
        unless doc_fd_css.blank?
          remove_prev_quote = doc_fd_css.xpath('//div/child::*[1][name()="blockquote"]')[3] # will show last 4 conversations apart from recent one
          remove_prev_quote.remove unless remove_prev_quote.blank?
        end
        last_reply_content = doc.at_css("body").inner_html 
      end
    end
    
    default_reply = "<br/><br/>#{signature}"

    if(!forward)
      requester_template = current_account.email_notifications.find_by_notification_type(EmailNotification::DEFAULT_REPLY_TEMPLATE).requester_template
      if(!requester_template.nil?)
        reply_email_template = Liquid::Template.parse(requester_template).render('ticket'=>ticket)
        default_reply = "<br/>#{reply_email_template}<br/>#{signature}"
      end 
    end
    content = default_reply+"<div class='freshdesk_quote'><blockquote class='freshdesk_quote'>On "+formated_date(last_conv.created_at)+
              "<span class='separator' /> , "+ last_reply_by +" wrote:"+
              last_reply_content+"</blockquote></div>"
    return content
  end

  def bind_last_reply (item, signature, forward = false)
    ticket = (item.is_a? Helpdesk::Ticket) ? item : item.notable
    last_conv = (item.is_a? Helpdesk::Note) ? item : 
                ((!forward && ticket.notes.visible.public.last) ? ticket.notes.visible.public.last : item)
    key = 'HELPDESK_REPLY_DRAFTS:'+current_account.id.to_s+':'+current_user.id.to_s+':'+ticket.id.to_s

    return ( get_key(key) || bind_last_conv(item, signature) )
  end

  def status_changed_time_value_hash (ticket)
    status_name = ticket.status_name
    status = ticket.status
    case status
      when RESOLVED
        return {:title => "#{status_name}", :method => "resolved_at"}
      when PENDING
        return {:title =>  "#{status_name}", :method => "pending_since"}
      when CLOSED
        return {:title => "#{status_name}", :method => "closed_at"}
      else
        return {:title => "#{status_name}", :method => "status_updated_at"}
    end
  end
  
  def default_twitter_body_val (ticket)
    if (ticket.tweet && ticket.tweet.tweet_type == 'mention')
     return "@#{ticket.requester.twitter_id}"
    else
     return ""
    end
  end
  
  def get_ticket_show_params(params, ticket_display_id)
    filters = {:filters => params.clone}
    
    if filters[:filters].blank?
      show_params = {:id=>ticket_display_id}
    else  
      filters[:filters].delete("action")
      filters[:filters].delete("controller")
      filters[:filters].delete("page")
      show_params = filters.merge!({:id=>ticket_display_id})
    end
    show_params
  end
  
end
