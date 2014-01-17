# encoding: utf-8
module Helpdesk::TicketsHelper
  
  include Wf::HelperMethods
  include TicketsFilter
  include Helpdesk::Ticketfields::TicketStatus
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Helpdesk::NoteActions
  include Integrations::AppsUtil
  include Helpdesk::TicketsHelperMethods
  include MetaHelperMethods
  include Faye::Token

  def view_menu_links( view, cls = "", selected = false )
    unless(view[:id] == -1)
      parallel_url = "/helpdesk/tickets/filter_options"
      query_str = view[:default] ? "?filter_name=#{view[:id]}" : "?filter_key=#{view[:id]}"
      link_to( ((content_tag(:span, "", :class => "icon ticksymbol") if selected).to_s + strip_tags(view[:name])).html_safe, 
        (view[:default] ? helpdesk_filter_view_default_path(view[:id]) : helpdesk_filter_view_custom_path(view[:id])) , 
        :class => ( selected ? "active #{cls}": "#{cls}"), :rel => (view[:default] ? "default_filter" : "" ), 
        :"data-pjax" => "#body-container", :"data-parallel-url" => "#{parallel_url}#{query_str}", 
        :"data-parallel-placeholder" => "#ticket-leftFilter")
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
        content_tag(:div, viewlist.map { |s| view_menu_links(s, "", (s[:name].to_s == selected_item.to_s)) }.to_s.html_safe, :class => "fd-menu", :id => menuid)
    end
    more_menu_drop.html_safe
  end
  
  def ticket_sidebar
    tabs = [["TicketProperties", t('ticket.properties').html_safe,         "ticket"],
            ["RelatedSolutions", t('ticket.suggest_solutions').html_safe,  "related_solutions", privilege?(:view_solutions)],
            ["Scenario",         t('ticket.execute_scenario').html_safe,   "scenarios",       feature?(:scenario_automations)],
            ["RequesterInfo",    t('ticket.requestor_info').html_safe,     "requesterinfo"],
            ["Reminder",         t('to_do').html_safe,                     "todo"],
            ["Tags",             t('tag.title').html_safe,                 "tags"],
            ["Activity",         t('ticket.activities').html_safe,         "activity"]]
        
    icons = ul tabs.map{ |t| 
                next if !t[3].nil? && !t[3]
                  link_to content_tag(:span, "", :class => t[2]) + 
                          content_tag(:em, t[1]), "#"+t[0], 
                                "data-remote-load" => ( url_for({ :action => "component", 
                                                                :component => t[2], 
                                                                :id => @ticket.id }) unless (tabs.first == t) )
               }, { :class => "rtPanel", "data-tabs" => "tabs" }
               
    panels = content_tag :div, tabs.collect{ |t| 
      if(tabs.first == t)
        content_tag :div, content_tag(:div, "") ,{:class => "rtDetails tab-pane active #{t[2]}", :id => t[0], :rel => "remote", :"data-remote-url" => "/helpdesk/tickets/component/#{@ticket.id}?component=ticket"}
      else
        content_tag :div, content_tag(:div, "", :class => "loading-block sloading loading-small "), :class => "rtDetails tab-pane #{t[2]}", :id => t[0]
      end
    }.to_s.html_safe, :class => "tab-content"
               
    (icons + panels).html_safe
  end
    
  def ticket_tabs
    tabs = [
            ['Pages',     t(".conversation").html_safe, @ticket_notes.total_entries],
            ['Timesheet', t(".timesheet").html_safe,    timesheets_size, 
                helpdesk_ticket_helpdesk_time_sheets_path(@ticket), 
                feature?(:timesheets) && privilege?(:view_time_entries)
            ]
           ]
    
    ul tabs.map{ |t| 
                  next if !t[4].nil? && !t[4]
                  link_to t[1] + (content_tag :span, t[2], :class => "pill #{ t[2] == 0 ? 'hide' : ''}", :id => "#{t[0]}Count"), "##{t[0]}", "data-remote-load" => t[3], :id => "#{t[0]}Tab"
                }, { :class => "tabs ticket_tabs", "data-tabs" => "tabs" }
                
  end

  def timesheets_size
    @ticket.time_sheets.size
  end
  
  def top_views(selected = "new_my_open", dynamic_view = [], show_max = 1)
    unless dynamic_view.empty?
      dynamic_view.concat([{ :id => -1 }])
    end
    
    default_views = [
      { :id => "new_my_open",  :name => t("helpdesk.tickets.views.new_my_open").html_safe,     :default => true },
      { :id => "all_tickets",  :name => t("helpdesk.tickets.views.all_tickets").html_safe,     :default => true },      
      { :id => "monitored_by", :name => t("helpdesk.tickets.views.monitored_by").html_safe,    :default => true },
      { :id => "spam"   ,      :name => t("helpdesk.tickets.views.spam").html_safe,            :default => true },
      { :id => "deleted",      :name => t("helpdesk.tickets.views.deleted").html_safe,         :default => true }
    ]
    top_views_array = [].concat(dynamic_view).concat(default_views)
    top_index = top_views_array.index{|v| v[:id] == selected} || 0

    cannot_delete = false
    selected_item =  top_views_array.select { |v| v[:id].to_s == selected.to_s }.first
    unless selected_item.blank?
      selected_item_name = selected_item[:name]
    else
      if selected.blank?
        selected_item_name = t("tickets_filter.unsaved_view")
      else
        selected_from_default = SELECTORS.select { |v| v.first == selected.to_sym }
        selected_item_name =  (selected_from_default.blank? ? default_views.first[:name] : selected_from_default.first[1]).to_s
      end
      cannot_delete = true
    end

    top_view_html = drop_down_views(top_views_array, selected_item_name, "leftViewMenu", selected.blank? ).to_s + 
      (!(cannot_delete or selected_item[:default]) ? (content_tag :div, (link_to t('delete'), {:controller => "wf/filter", :action => "delete_filter", 
        :id => selected_item[:id]}, 
        {:method => :delete, :confirm => t("wf.filter.view.delete"), :id => 'delete_filter'}), 
        :id => "view_manage_links") : "")
  end
  
  def filter_select( prompt = t('helpdesk.tickets.views.select'))    
    selector = select("select_view", "id", SELECTORS.collect { |v| [v[1], helpdesk_filter_tickets_path(filter(v[0]))] },
              {:prompt => prompt}, { :class => "customSelect" })        
  end

  def filter(selector = nil)
    selector ||= current_selector
  end
  
  def filter_count(selector=nil)
    Sharding.run_on_slave do
     TicketsFilter.filter(filter(selector), current_user, current_account.tickets.permissible(current_user)).count
    end
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
    return @cached_filter_data[:wf_order_type].to_sym if @cached_filter_data && !@cached_filter_data[:wf_order_type].blank?
    # return @cached_filter_data[:wf_order_type].to_sym if @cached_filter_data && !@cached_filter_data[:wf_order_type].blank?
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
  
  def bind_last_conv (item, signature, forward = false, quoted=true)
    ticket = (item.is_a? Helpdesk::Ticket) ? item : item.notable
    last_conv = (item.is_a? Helpdesk::Note) ? item : 
                ((!forward && (last_visible_note = ticket.notes.visible.public.last)) ? last_visible_note : item)
    if (last_conv.is_a? Helpdesk::Ticket)
      last_reply_by = (h(last_conv.requester.name) || '')+"<"+(last_conv.requester.email || '')+">"
      last_reply_time = last_conv.created_at
      last_reply_content = last_conv.description_html
    else
      last_reply_by = (h(last_conv.user.name) || '')+"<"+(last_conv.user.email || '')+">" 
      last_reply_by  = (h(ticket.reply_name) || '')+"<"+(ticket.reply_email || '')+">" unless last_conv.user.customer?       
      last_reply_time = last_conv.created_at
      last_reply_content = last_conv.full_text_html
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
    
    default_reply = (signature.blank?)? "<p/><br/>": "<p/><div>#{signature}</div>" #Adding <p> tag for the IE9 text not shown issue

    if(!forward)
      requester_template = current_account.email_notifications.find_by_notification_type(EmailNotification::DEFAULT_REPLY_TEMPLATE).get_reply_template(ticket.requester)
      if(!requester_template.nil?)
        reply_email_template = Liquid::Template.parse(requester_template).render('ticket'=>ticket,'helpdesk_name' => ticket.account.portal_name)
        default_reply = (signature.blank?)? "<p/><div>#{reply_email_template}</div>" : "<p/><div>#{reply_email_template}<br/>#{signature}</div>" #Adding <p> tag for the IE9 text not shown issue
      end 
    end

    return default_reply unless quoted or forward
    
    content = default_reply+"<div class='freshdesk_quote'><blockquote class='freshdesk_quote'>On "+formated_date(last_conv.created_at)+
              "<span class='separator' /> , "+ last_reply_by +" wrote:"+
              last_reply_content.to_s+"</blockquote></div>"
    return content
  end

  def bind_last_reply (item, signature, forward = false, quoted = false)
    ticket = (item.is_a? Helpdesk::Ticket) ? item : item.notable
    # last_conv = (item.is_a? Helpdesk::Note) ? item : 
                # ((!forward && ticket.notes.visible.public.last) ? ticket.notes.visible.public.last : item)
    key = 'HELPDESK_REPLY_DRAFTS:'+current_account.id.to_s+':'+current_user.id.to_s+':'+ticket.id.to_s

    return ( get_tickets_redis_key(key) || bind_last_conv(item, signature, false, quoted) )
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

  def multiple_emails_container(emails, label = "To: ")
    html = ""
    unless emails.blank?
      if emails.length < 3
        html << content_tag(:span, 
                            "#{label}" + emails.join(", ").html_safe , 
                            :class => "") 
      else
        html << content_tag(:span, 
                            ("#{label}" + emails[0,2].join(", ").html_safe + 
                            "<span class='toEmailMoreContainer hide'>,&nbsp;" + 
                            emails[2,emails.length].join(", ").html_safe + 
                            " </span> <a href='javascript:showHideToEmailContainer();'  class='toEmailMoreLink'> #{emails.length-2} " + 
                            t('ticket_cc_email_more')+"</a>").html_safe , :class => "")
      end
    end
    html.html_safe
  end
  
  def visible_page_numbers(options,current_page,total_pages)
    inner_window, outer_window = options[:inner_window].to_i, options[:outer_window].to_i
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

  def ticket_pagination_html(options,full_pagination=false)
    prev = 0
    current_page = options[:current_page]
    per_page = params[:per_page]
    no_of_pages = options[:total_pages]
    visible_pages = full_pagination ? visible_page_numbers(options,current_page,no_of_pages) : []
    content = ""
    content << "<div class='toolbar_pagination_full'>" if full_pagination
    if current_page == 1
      content << "<span class='disabled prev_page'>#{options[:previous_label]}</span>"
    else
      content << "<a class='prev_page' href='/helpdesk/tickets?page=#{(current_page-1)}' title='Previous'>#{options[:previous_label]}</a>"
    end
    visible_pages.each do |index|
      # detect gaps:
      content << '<span class="gap">&hellip;</span>' if prev and index > prev + 1
      prev = index
      if( index == current_page )
        content << "<span class='current'>#{index}</span>"
      else
        content << "<a href='/helpdesk/tickets?page=#{index}' rel='next'>#{index}</a>"
      end
    end
    if current_page == no_of_pages
      content << "<span class='disabled next_page'>#{options[:next_label]}</span>"
    else
      content << "<a href='/helpdesk/tickets?page=#{(current_page+1)}' class='next_page' rel='next' title='Next'>#{options[:next_label]}</a>"
    end
    content << "</div>" if full_pagination
    content
  end

  def auto_refresh_params
    @data = @data || {
      :userId      => current_user.id,
      :accountId   => current_account.id,
      :domainName  => current_account.full_domain,
      :auth        => generate_hmac_token(current_user),
      :secure      => current_account.ssl_enabled? 
    }.to_json.html_safe
  end

  def auto_refresh_channel
    Faye::AutoRefresh.channel(current_account)
  end

  def faye_host
    "#{request.protocol}#{NodeConfig["faye_host"]}"
  end

end

def to_event_data_scenario(va_rule)
  rule_info = {
    name: va_rule.name,
    description: va_rule.description,
    id: va_rule.id,
    activities: Va::Action.activities
  }.to_json
end
