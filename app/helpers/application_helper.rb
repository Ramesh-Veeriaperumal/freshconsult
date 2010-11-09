# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  include SavageBeast::ApplicationHelper
  
  def show_flash
    [:notice, :error].collect {|type| content_tag('div', flash[type], :id => type) if flash[type] }
  end

  def tab(title, url, cls = false)
    content_tag('li', link_to(content_tag('span', truncate(strip_tags(title), :length => 15)), url), :class => cls) 
  end

  def navigation_tabs
    tabs = [
      ['helpdesk/dashboard',  'Dashboard',    permission?(:manage_tickets)],
      ['helpdesk/issues',    'Issues',       permission?(:manage_tickets)],
      ['helpdesk/tickets',    'Tickets',      permission?(:manage_tickets)],
      ['helpdesk/tags',       'Tags',         permission?(:manage_tickets)],
      ['helpdesk/guides',     'User Guides',  permission?(:manage_knowledgebase)],
      ['helpdesk/articles',   'Articles',     permission?(:manage_knowledgebase)],
      ['/forums', 'Forums', permission?(:manage_knowledgebase)]
    ]

    history_active = false;

    history = (session[:helpdesk_history] || []).reverse.map do |h| 
      active = h[:url][:id] == @item.to_param && 
               h[:url][:controller] == params[:controller]

      history_active ||= active

      tab(h[:title], h[:url], "#{active ? :active : :history} #{ h[:class] || '' }") 
    end

    navigation = tabs.map do |s| 
      next unless s[2]
      active = (!history_active && params[:controller] == s[0]) || (s[1] == @selected_tab) #selected_tab hack by Shan
      tab(s[1], {:controller => s[0], :action => :index}, active && :active) 
    end

    spacer = content_tag('li', '', :class => 'spacer')

    navigation + [spacer] + history  
  end

  def check_box_link(text, checked, check_url, check_method, uncheck_url, uncheck_method = :post)
    form_tag("", :method => :put) +
    check_box_tag("", 1, checked, :onclick => %{
      this.form.action = this.checked ? '#{check_url}' : '#{uncheck_url}';
      Element.down(this.form, "input[name=_method]").value = this.checked ? '#{check_method}' : '#{uncheck_method}';
      this.form.submit();
    }) +
    "<label class=\"reminder #{ checked ? "checked" : "unchecked" }\">#{text}</label>" +
    "</form>"
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

end
