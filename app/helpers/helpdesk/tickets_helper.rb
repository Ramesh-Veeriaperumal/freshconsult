module Helpdesk::TicketsHelper

  DEFAULT_FILTER = [:new_and_my_open]

  #CONTEXTS = [:all, :open]
  CONTEXTS = []

  SELECTORS = [
    [[:new_and_my_open],  "New & My Open Tickets"  ],
    [[:my_open],          "My Open Tickets"  ],
    [[:my_resolved],      "My Resolved Tickets" ],
    [[:my_closed],        "My Closed Tickets"  ],
    [[:my_due_today],     "My Tickets Due Today"  ],
    [[:my_overdue],       "My Overdue Tickets"  ],
    [[:my_on_hold],       "My Tickets On Hold"  ],
    [[:monitored_by],     "Tickets I'm Monitoring"  ],
    [[:my_all],           "All My Tickets"  ],
    
    [[:new],              "New Tickets" ],
    [[:open],             "Open Tickets"  ],
    [[:new_and_open],     "New & Open Tickets"  ],
    [[:resolved],         "Resolved Tickets"  ],
    [[:closed],           "Closed Tickets"  ],
    [[:due_today],        "Tickets Due Today" ],
    [[:overdue],          "Overdue Tickets" ],
    [[:on_hold],          "Tickets On Hold" ],
    [[:all],              "All Tickets ", ],
    
    #[[:unassigned],      "New Tickets" ],
    #[[:responded_by],    "My Tickets"  ],
    #[[:visible],         "All Tickets" ],
    [[:spam],             "Spam", ],
    [[:deleted],          "Trash",  ]
  ]

  SELECTOR_NAMES = Hash[*SELECTORS.inject([]){ |a, v| a += [v[0], v[1]] }]
  SELECTOR_CONTEXTS = Hash[*SELECTORS.inject([]){ |a, v| a += [v[0], v[2]] }]

  def filter_list
    SELECTORS.collect { |f| content_tag('li', leader(filter_link(f[0]), filter_count(f[0]).to_s)) }
  end
  
  def filter_select
    select ("select_view", "id", SELECTORS.collect {|v| [v[1], helpdesk_filter_tickets_path(filter(v[0]))]}, { :prompt => "Select View..."})
  end

  def leader(left, right)
    # "<div class=\"leader-right\">#{right}</div><div class=\"leader-left\">#{left}</div><div class=\"clear\"></div>"
    "#{left} (#{right})"    
  end

  def filter_link(selector)
    if selector == current_selector
     SELECTOR_NAMES[selector]
    else
      link_to(SELECTOR_NAMES[selector], helpdesk_filter_tickets_url(filter(selector)))
    end
  end

  def filter(selector = nil)
    selector ||= current_selector
    (SELECTOR_CONTEXTS[selector] || current_context) + selector
  end

  def current_filter
    (params[:filters] || DEFAULT_FILTER).map { |f| f.to_sym } 
  end

  def current_selector
    current_filter.reject { |f| CONTEXTS.include? f }
  end

  def current_context
    current_filter.select { |f| CONTEXTS.include? f }
  end

  def filter_count(selector=nil)
    Helpdesk::Ticket.filter(filter(selector), current_user, current_account.tickets).count
  end

  def filter_title(selector)
    "#{SELECTOR_NAMES[selector]} (#{filter_count(selector)})"
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

  def search_clear
  end

end
