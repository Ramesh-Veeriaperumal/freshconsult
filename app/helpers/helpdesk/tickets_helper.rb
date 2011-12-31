module Helpdesk::TicketsHelper
  
  include Wf::HelperMethods
  include TicketsFilter
  
  def view_menu_links( view, cls = "", selected = false )
    unless(view[:id] == -1)
      link_to(strip_tags(view[:name]), (view[:default] ? helpdesk_filter_view_default_path(view[:id]) : helpdesk_filter_view_custom_path(view[:id])), :class => ( selected ? "active #{cls}": "#{cls}" ))
    else
      content_tag(:span, "", :class => "seperator")
    end  
  end
  
  def drop_down_views(viewlist, menuid = "leftViewMenu")
    unless viewlist.empty?
      more_menu_drop = 
        content_tag(:div, ( link_to "#{viewlist.size-1} more views", "", { :class => "drop-right nav-trigger", :menuid => "##{menuid}" }), :class => "link-item" ) +
        content_tag(:div, viewlist.map { |s| view_menu_links(s) }, :class => "fd-menu", :id => menuid)
    end
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

    if( show_max-1 < top_index )
      top_views_array.insert(show_max-1, top_views_array.slice!(top_index))
    end
    
    top_view_html = 
        (top_views_array.shift(show_max).map do |s|
            view_menu_links(s, "link-item", (s[:id] == selected)) unless( s[:id] == -1 )
        end).to_s + drop_down_views(top_views_array).to_s
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
  	cookies[:wf_order] = (params[:wf_order] ? params[:wf_order] : ( (!cookies[:wf_order].blank?) ? cookies[:wf_order] : DEFAULT_SORT )).to_sym
  end

  def current_wf_order_type 
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
  
  def subject_style(ticket, class_name = "need-attention")
    if ticket.active? && ticket.ticket_states.need_attention 
      class_name
    end
  end
  
  def bind_last_conv (ticket, signature)
 
    last_conv = ticket.notes.public.last ? ticket.notes.public.last : ticket
    
    if (last_conv.is_a? Helpdesk::Ticket)
      last_reply_by = (last_conv.requester.name || '')+"&lt;"+(last_conv.requester.email || '')+"&gt;"
      last_reply_time = last_conv.created_at
      last_reply_content = last_conv.description_html
    else
      last_reply_by = (last_conv.user.name || '')+"&lt;"+(last_conv.user.email || '')+"&gt;"
      last_reply_time = last_conv.created_at
      last_reply_content = last_conv.body_html
    end
    content = "<br/><br/>"+signature+"<div class='freshdesk_quote'><blockquote class='freshdesk_quote'>On "+formated_date(last_conv.created_at)+
              "<span class='separator' /> , "+ last_reply_by +" wrote:"+
              last_reply_content+"</blockquote></div>"
    return content
    
  end
  
  def status_changed_time_value_hash (status)
    case status
      when TicketConstants::STATUS_KEYS_BY_TOKEN[:resolved]
        return {:title => t('ticket_resolved_at_time'), :method => "resolved_at"}
      when TicketConstants::STATUS_KEYS_BY_TOKEN[:pending]
        return {:title =>  t('ticket_pending_since_time'), :method => "pending_since"}
      when TicketConstants::STATUS_KEYS_BY_TOKEN[:closed]
        return {:title => t('ticket_closed_at_time'), :method => "resolved_at"}
    end
  end
  
end
