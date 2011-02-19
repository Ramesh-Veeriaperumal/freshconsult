# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
  
  include SavageBeast::ApplicationHelper
  include Juixe::Acts::Voteable
  
  def show_flash
    [:notice, :error].collect {|type| content_tag('div', flash[type], :id => type, :class => "flash_info") if flash[type] }
  end

  def tab(title, url, cls = false)
    content_tag('li', link_to(content_tag('span') + strip_tags(title), url), :class => cls) 
  end

  def navigation_tabs
    tabs = [
      ['helpdesk/dashboard',  'Dashboard',    permission?(:manage_tickets)],
      #['helpdesk/issues',    'Issues',       permission?(:manage_tickets)],
      ['helpdesk/tickets',    'Tickets',      permission?(:manage_tickets)],
      #['helpdesk/tags',      'Tags',         permission?(:manage_tickets)],
      ['solution/categories',    'Solutions',    permission?(:manage_knowledgebase)],      
      ['/categories',             'Forums',       permission?(:manage_knowledgebase)],      
      ['/contacts',              'Customers',    permission?(:manage_users)],
      #['helpdesk/articles',  'Articles',     permission?(:manage_knowledgebase)],
      ['/admin/home',         'Admin',        permission?(:manage_users)]
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
      tab(s[1], {:controller => s[0], :action => :index}, active && :active) 
    end

    spacer = content_tag('li', '', :class => 'spacer')

    navigation #+ [spacer] + history  
  end
  
  def check_box_link(text, checked, check_url, check_method, uncheck_url, uncheck_method = :post)
    form_tag("", :method => :put) +
    check_box_tag("", 1, checked, :onclick => %{
      this.form.action = this.checked ? '#{check_url}' : '#{uncheck_url}';
      Element.down(this.form, "input[name=_method]").value = this.checked ? '#{check_method}' : '#{uncheck_method}';
      this.form.submit();
    }) +
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
  
  def comment_path(args_hash, link_display = 'comment')
    link_to(link_display, "#{helpdesk_ticket_path args_hash['ticket_id']}##{args_hash['comment_id']}")
  end
  
  def email_response_path(args_hash)
    comment_path(args_hash, 'email response')
  end
  #Liquid ends here..
  
  #Ticket place-holders, which will be used in email and comment contents.
  def ticket_placeholders
    [
      ['{{ticket.subject}}', 'Ticket subject.'],
      ['{{ticket.description}}', 'Ticket description.'],
      ['{{ticket.display_id}}', 'Unique ticket display ID.'],
      ['{{ticket.url}}', 'Full URL path to ticket.'],
      ['{{ticket.status}}', 'Ticket status.'],
      ['{{ticket.priority}}', 'Ticket priority.'],
      ['{{ticket.source}}', 'The source channel of the ticket.'],
      ['{{ticket.ticket_type}}', 'Ticket type.'],
      ['{{ticket.due_by_time}}', 'Ticket due by time.'],
      ['{{ticket.requester.name}}', 'Name of the requester who raised the ticket.'],
      ['{{ticket.requester.email}}', "Requester's email."],
      ['{{ticket.requester.company_name}}', "Requester's company name."], #??? should it be requester.company.name?!
      ['{{ticket.group.name}}', 'Ticket group.'],
      ['{{ticket.agent.name}}', 'Name of the agent who is currently working on the ticket.'],
      ['{{ticket.agent.email}}', "Agent's email."],
      ['{{ticket.tags}}', 'Ticket tags.'],
      ['{{ticket.latest_comment}}', 'Latest comment for this ticket.'],
      ['{{ticket.latest_public_comment}}', 'Latest public comment for this ticket.']
    ]
  end
  
  # Avatar helper for user profile image
  # :medium and :small size of the original image will be saved as an attachment to the user 
  def user_avatar( avatar, profile_size = :thumb, profile_class = "preview_pic" )
    content_tag( :div, (image_tag (avatar) ? avatar.content.url(profile_size) : "/images/icons/profile_blank.gif"), :class => profile_class)
  end
  
end
