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
  include Helpdesk::TicketFilterMethods
  include Faye::Token
  
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
        content_tag :div, content_tag(:div, "") ,{:class => "rtDetails tab-pane active #{t[2]}", :id => t[0], :rel => "remote", :"data-remote-url" => "/helpdesk/tickets/#{@ticket.id}/component?component=ticket"}
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
  
  def sort_by_text(sort_key, order)
    help_text = [
      [ :due_by     ,   'Showing Latest Due by time'  ],
      [ :created_at ,   'Showing Tickets Date Created' ],
      [ :updated_at ,   'Showing Tickets Last Modified'],
      [ :priority   ,   'Priority',    ],
      [ :status,        'Status',      ],
    ]
  end
   
  def current_sort
    cookies[:sort] = (params[:sort] ? params[:sort] : ( (!cookies[:sort].blank?) ? cookies[:sort] : DEFAULT_SORT )).to_sym 
  end
 
  def current_sort_order 
    cookies[:sort_order] = (params[:sort_order] ? params[:sort_order] : ( (!cookies[:sort_order].blank?) ? cookies[:sort_order] : DEFAULT_SORT_ORDER )).to_sym
  end

  def cookie_sort 
     "#{current_sort} #{current_sort_order}"
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

  def bind_last_reply(item, signature, forward = false, quoted = false)
    ticket = (item.is_a? Helpdesk::Ticket) ? item : item.notable
    # last_conv = (item.is_a? Helpdesk::Note) ? item : 
                # ((!forward && ticket.notes.visible.public.last) ? ticket.notes.visible.public.last : item)
    key = 'HELPDESK_REPLY_DRAFTS:'+current_account.id.to_s+':'+current_user.id.to_s+':'+ticket.id.to_s

    return ( get_tickets_redis_key(key) || bind_last_conv(item, signature, false, quoted) )
  end

  def bind_last_conv(item, signature, forward = false, quoted = true)    
    ticket = (item.is_a? Helpdesk::Ticket) ? item : item.notable
    default_reply = (signature.blank?)? "<p/><br/>": "<p/><div>#{signature}</div>"
    quoted_text = ""

    if quoted or forward
      quoted_text = quoted_text(item, forward)
    else
      default_reply = parsed_reply_template(ticket, signature)
    end 

    "#{default_reply} #{quoted_text}"
  end

  def parsed_reply_template(ticket, signature)   
    # Adding <p> tag for the IE9 text not shown issue
    # default_reply = (signature.blank?)? "<p/><br/>": "<p/><div>#{signature}</div>"
 
    requester_template = current_account.email_notifications.find_by_notification_type(EmailNotification::DEFAULT_REPLY_TEMPLATE).get_reply_template(ticket.requester)
    if(!requester_template.nil?)
      reply_email_template = Liquid::Template.parse(requester_template).render('ticket' => ticket,'helpdesk_name' => ticket.account.portal_name)
      # Adding <p> tag for the IE9 text not shown issue
      default_reply = (signature.blank?)? "<p/><div>#{reply_email_template}</div>" : "<p/><div>#{reply_email_template}<br/>#{signature}</div>"
    end 
 
    default_reply
  end

  def quoted_text(item, forward = false)
    # item can be note/ticket 
    # If its a ticket we will be getting the last note from the ticket
    @last_item = (item.is_a?(Helpdesk::Note) or forward) ? item : (item.notes.visible.public.last || item)

    %(<div class="freshdesk_quote">
        <blockquote class="freshdesk_quote">#{t('ticket.quoted_text.wrote_on')} #{formated_date(@last_item.created_at)}
          <span class="separator" />, #{user_details_template(@last_item)} #{t('ticket.quoted_text.wrote')}:
          #{ (@last_item.description_html || extract_quote_from_note(@last_item).to_s)}
        </blockquote>
       </div>) 
  end

  def user_details_template(item)
    user = (item.is_a? Helpdesk::Ticket) ? item.requester :
            ((item.user.customer?) ? item.user :
              { "name" => item.notable.reply_name, "email" => item.notable.reply_email })

    %( #{h(user['name'])} &lt;#{h(user['email'])}&gt; )
  end

  def extract_quote_from_note(note)
    unless note.full_text_html.blank?
      doc = Nokogiri::HTML(note.full_text_html)
      doc_fd_css = doc.css('div.freshdesk_quote')
      unless doc_fd_css.blank?
        # will show last 4 conversations apart from recent one
        remove_prev_quote = doc_fd_css.xpath('//div/child::*[1][name()="blockquote"]')[3] 
        remove_prev_quote.remove unless remove_prev_quote.blank?
      end
      doc.at_css("body").inner_html
    end
  end

  
  def default_twitter_body_val (ticket)
    if (ticket.tweet && ticket.tweet.tweet_type == 'mention')
     return "@#{ticket.requester.twitter_id}"
    else
     return ""
    end
  end

  def multiple_emails_container(emails, label = "To: ")
    html = ""
    unless emails.blank?
      if emails.length < 3
        html << content_tag(:span, (label + html_escape(emails.join(", "))).html_safe)
      else
        html << content_tag(:span, (label + html_escape(emails[0,2].join(", ")) + 
                                    content_tag(:span, html_escape(', ' + emails[2,emails.length].join(", ")), :class => 'toEmailMoreContainer hide') +
                                    link_to(" #{emails.length-2} #{t('ticket_cc_email_more')}", 'javascript:showHideToEmailContainer();', :class => 'toEmailMoreLink')).html_safe)
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

  def shortcut_options(key)
    key = 'pagination.'+key
    options = "data-keybinding='#{shortcut(key)}' data-highlight='true'"
    options
  end

  def ticket_pagination_html(options,full_pagination=false)
    prev = 0
    current_page = options[:current_page]
    per_page = params[:per_page]
    no_of_pages = options[:total_pages]
    visible_pages = full_pagination ? visible_page_numbers(options,current_page,no_of_pages) : []
    tooltip = 'tooltip' if !full_pagination

    content = ""
    content << "<div class='toolbar_pagination_full'>" if full_pagination
    if current_page == 1
      content << "<span class='disabled prev_page'>#{options[:previous_label]}</span>"
    else
      content << "<a class='prev_page #{tooltip}' href='/helpdesk/tickets?page=#{(current_page-1)}' 
                      title='Previous' 
                      #{shortcut_options('previous') unless full_pagination} >#{options[:previous_label]}</a>"
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
      content << "<a class='next_page #{tooltip}' href='/helpdesk/tickets?page=#{(current_page+1)}' 
                      rel='next' title='Next' 
                      #{shortcut_options('next') unless full_pagination} >#{options[:next_label]}</a>"
    end
    content << "</div>" if full_pagination
    content
  end

  def faye_auth_params
    @data = @data || {
      :userId      => current_user.id,
      :name       => current_user.name,
      :accountId   => current_account.id,
      :domainName  => current_account.full_domain,
      :auth        => generate_hmac_token(current_user),
      :secure      => current_account.ssl_enabled? 
    }.to_json.html_safe
  end

  def auto_refresh_channel
    Faye::AutoRefresh.channel(current_account)
  end

  def agent_collision_index_channel
    Faye::AgentCollision.channel(current_account);
  end

  def agent_collision_ticket_view_channel(ticket_id)
    Faye::AgentCollision.ticket_view_channel(current_account,ticket_id)
  end

  def agent_collision_ticket_reply_channel(ticket_id)
    Faye::AgentCollision.ticket_replying_channel(current_account,ticket_id)
  end

  def agent_collision_ticket_channel(ticket_id)
    Faye::AgentCollision.ticket_channel(current_account,ticket_id)
  end


  def faye_host
    "#{request.protocol}#{NodeConfig["faye_host"]}"
  end

  def faye_server
    "#{request.protocol}#{NodeConfig["faye_server"]}"
  end

  def freshfone_audio_dom(notable = nil)
      notable = notable || @ticket
      call = notable.freshfone_call
      dom = ""
      if call.present? && call.recording_url
        dom << tag(:br)
        dom << content_tag(:span, content_tag(:b, I18n.t('freshfone.ticket.recording')))
        if call.recording_audio
          dom << content_tag(:div, content_tag(:div, link_to('', call.recording_audio, :type => 'audio/mp3',
           :class => 'call_duration', :'data-time' => call.call_duration), :class => 'ui360'), :class => 'freshfoneAudio')
          dom.html_safe
        else
          dom << tag(:br) << content_tag(:div, raw(I18n.t('freshfone.recording_on_process')), :class => 'freshfoneAudio_text')
        end
      end
      return raw(dom)
  end

  # ITIL Related Methods starts here

  def load_sticky
    render("helpdesk/tickets/show/sticky")
  end

  def itil_ticket_tabs
  end

  def ci_fields(ticket_form)
  end

  def itil_ticket_filters
    ""
  end

  # ITIL Related Methods ends here

end

def to_event_data_scenario(va_rule)
  rule_info = {
    name: va_rule.name,
    description: va_rule.description,
    id: va_rule.id,
    activities: Va::Action.activities
  }.to_json
end
