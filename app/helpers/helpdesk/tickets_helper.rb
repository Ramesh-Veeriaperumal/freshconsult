module Helpdesk::TicketsHelper
  
  include TicketsFilter
  
  def filter_select
    select("select_view", "id", SELECTORS.collect { |v| [v[1], helpdesk_filter_tickets_path(filter(v[0]))] },
              {:prompt => "Select View..."})
  end

  def filter(selector = nil)
    selector ||= current_selector
  end
  
  def filter_count(selector=nil)
    TicketsFilter.filter(filter(selector), current_user, current_account.tickets).count
  end

  def current_filter
    (params[:filters] || DEFAULT_FILTER).map { |f| f.to_sym } 
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

  def search_clear
  end

end
