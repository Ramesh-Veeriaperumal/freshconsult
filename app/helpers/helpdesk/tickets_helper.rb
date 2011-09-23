module Helpdesk::TicketsHelper
  
  include Wf::HelperMethods
  include TicketsFilter
  
  def filter_select( prompt = t('helpdesk.tickets.views.select'))    
    selector = select("select_view", "id", SELECTORS.collect { |v| [v[1], helpdesk_filter_tickets_path(filter(v[0]))] },
              {:prompt => prompt}, { :class => "customSelect" })        
  end

  def filter(selector = nil)
    selector ||= current_selector
  end
  
  def filter_count(selector=nil)
    TicketsFilter.filter(filter(selector), current_user, current_account.tickets).count
  end

  def current_filter
    cookies[:filters] = (params[:filters] ? params[:filters][0] : ( (!cookies[:filters].blank?) ? cookies[:filters] : DEFAULT_FILTER )).to_sym
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

  def search_clear
 end

 



end
