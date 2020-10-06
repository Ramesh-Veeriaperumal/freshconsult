# encoding: utf-8
module Helpdesk::TicketsHelper

  include Wf::HelperMethods# TODO-RAILS3 uninitialized constant Wf::HelperMethods:
  include TicketsFilter
  include Helpdesk::Ticketfields::TicketStatus
  include Redis::RedisKeys
  include Redis::TicketsRedis
  include Redis::OthersRedis
  include Helpdesk::NoteActions
  include Integrations::AppsUtil
  include Helpdesk::TicketsHelperMethods
  include MetaHelperMethods
  include Helpdesk::TicketFilterMethods
  include ParserUtil
  include Marketplace::ApiHelper
  include AutocompleteHelper
  include Helpdesk::AccessibleElements
  include Concerns::TicketsViewConcern
  include Cache::Memcache::Helpdesk::TicketTemplate #Methods for tkt templates count
  include Cache::FragmentCache::Base # Methods for fragment caching
  include Helpdesk::SpamAccountConstants
  include Redis::OthersRedis
  include Redis::RedisKeys

  def is_twitter_blocked?
    redis_key_exists?(TWITTER_APP_BLOCKED)
  end

  # Methods: bind_last_reply, bind_last_conv, parsed_reply_template, quoted_text, user_details_template,
  # extract_quote_from_note - moved to Concerns::TicketsViewConcern

  
  def draft_key
    HELPDESK_REPLY_DRAFTS % { :account_id => current_account.id, :user_id => current_user.id,
      :ticket_id => @ticket.id}
  end

  def ticket_sidebar
    tabs = [["TicketProperties", t('ticket.properties').html_safe,         "ticket"],
            ["RelatedSolutions", t('ticket.suggest_solutions').html_safe,  "related_solutions", privilege?(:view_solutions)],
            ["Scenario",         t('ticket.execute_scenario').html_safe,   "scenarios",       true],
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
                helpdesk_ticket_time_sheets_path(@ticket),
                current_account.timesheets_enabled? && privilege?(:view_time_entries)
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

  def nested_ticket_field_value(item, field)
    field_value = {}
    field.nested_levels.each do |ff|
      field_value[(ff[:level] == 2) ? :subcategory_val : :item_val] = fetch_custom_field_value(item, ff[:name])
    end
    field_value.merge!({:category_val => fetch_custom_field_value(item, field.field_name)})
  end

  def fetch_custom_field_value(item, field_name)
    item.is_a?(Helpdesk::Ticket) ? item.safe_send(field_name) : item.custom_field_value(field_name)
  end

  def ticket_field_element(field, dom_type, attributes, pl_value_id=nil)
    if field.visible_in_view_form? && ((dom_type == "dropdown") ||
                                       (dom_type == "dropdown_blank") ||
                                       (dom_type == "nested_field"))
      object_name = "#{:helpdesk_ticket.to_s}#{ ( !field.is_default_field? ) ? '[custom_field]' : '' }"
      checkbox = check_box_tag object_name+"_"+field.field_name+"_label",
                               "",
                               false,
                               :class => "update-check-for-fields"
      label = label_tag(object_name+"_"+field.field_name+"_label",
                        (checkbox + field.label),
                        :rel => "inputcheckbox")
      section_class = " dynamic_sections" if field.section_dropdown?
      if field.field_type == "nested_field"
        element = label + nested_field_tag(object_name,
                                 field.field_name,
                                 field,
                                 {:include_blank => t('select'),
                                  :selected => {},
                                  :pl_value_id => pl_value_id},
                                 {:class => "#{dom_type} select2",
                                  :rel => "inputselectbox"},
                                 {},
                                 false)
      elsif field.field_type == "default_company"
        element = label + render_autocomplete({ :selected_values => [],
                                                :max_limit => 1,
                                                :type => :companies,
                                                :include_none => true,
                                                :bulk_actions => true })
      else
        element = label + select(object_name,
                      field.field_name,
                      field.html_unescaped_choices,
                      {:include_blank => t('select'),
                        :selected => t('select')},
                      {:class => "#{dom_type} #{section_class} select2" ,
                        :rel => "inputselectbox"})
      end
      content_tag :div, element.html_safe, attributes
    else
      ""
    end
  end

  def construct_bulk_skill_edit
    account_skills = sorted_account_skills if privilege?(:edit_ticket_skill)
    return '' unless account_skills.present?
    object_name = "#{:helpdesk_ticket.to_s}"
    checkbox = check_box_tag object_name + "_skill_label",
                             "",
                             false,
                             :class => "update-check-for-fields"
    label = label_tag(object_name+"_skill_label",
                      (checkbox + t("ticket_fields.fields.skill_required")),
                      :rel => "inputcheckbox")
    element = label + select(object_name,
                  'skill_id',
                  account_skills,
                  {:include_blank => t('select'),
                    :selected => t('select')},
                  {:class => "dropdown select2" ,
                    :rel => "inputselectbox"})
    content_tag :div, element.html_safe, :class => "field-item skill"
  end

  def construct_skill_edit ticket
    account_skills = sorted_account_skills if @ticket.group.present? && @ticket.group.skill_based_round_robin_enabled?
    return '' unless account_skills.present?
    field_value = @ticket.skill_id
    field_label = t("ticket_fields.fields.skill_required")
    object_name = "#{:helpdesk_ticket.to_s}"

    label = label_tag object_name+"_skill_id", field_label.html_safe
    element = label + select('helpdesk_ticket', 'skill_id', account_skills, { :include_blank => "...", :selected => field_value},{:class => " select2", :disabled => !privilege?(:edit_ticket_skill), "data-domhelper-name" => "ticket-properties-" + 'skill_id' })
    content_tag :li, element.html_safe, :class => "dropdown field #{ privilege?(:edit_ticket_skill) ? '' : 'disabled'}"
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

  def trash_in_progress?
    key_exists?(EMPTY_TRASH_TICKETS % {:account_id =>  current_account.id})
  end

  def spam_in_progress?
    key_exists?(EMPTY_SPAM_TICKETS % {:account_id =>  current_account.id})
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
      options_for_select(current_account.helpdesk_sources.default_ticket_sources.map { |i| [i[1], i[2]] }, params[:v].to_i),
      html)

    o << select_tag(
      'search-urgent',
      options_for_select({"High" => 1, "Normal" => 0}, params[:v].to_i),
      html)

    o.join
  end

  def reply_draft(item, signature)
    last_reply_info = @ticket.draft
    if last_reply_info.exists?
      {
        draft_text: last_reply_info.body,
        draft_cc:  last_reply_info.cc_emails,
        draft_bcc: last_reply_info.bcc_emails 
      }
    else
      {
        draft_text: bind_last_conv(item, signature, false, false),
        draft_cc: @to_cc_emails,
        draft_bcc: bcc_drop_box_email 
      }
    end
  end

  def forward_template_draft(item, signature)
    {"draft_text" => bind_last_conv(item, signature, true, false)}
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

  def multiple_cc_emails_container cc_emails_hash
    html  = ""
    label = "Cc: "
    cc_emails_hash[:cc_emails] = cc_emails_hash.blank? ? [] : (cc_emails_hash[:tkt_cc] || cc_emails_hash[:cc_emails])
    if cc_emails_hash[:cc_emails].present? || cc_emails_hash[:dropped_cc_emails].present?
      html << (label + ticket_cc_info(cc_emails_hash) ).html_safe
    end
    html
  end

  def ticket_popover_details ticket
    return "" if ticket.cc_email_hash.blank?
     if ticket.cc_email_hash[:tkt_cc].present? || ticket.cc_email_hash[:dropped_cc_emails].present?
      cc_emails_string =  CcViewHelper.new(nil, ticket.cc_email_hash[:tkt_cc], ticket.cc_email_hash[:dropped_cc_emails]).cc_agent_hover_content
    end
    cc_array = []
    cc_array << [t('to'), form_email_strings(ticket.to_email)] if ticket.to_email.present?
    cc_array << [t('helpdesk.shared.cc'), "#{cc_emails_string}"] if cc_emails_string.present?
    cc_array.map{|c| "<dt>#{c.first} : </dt><dd>#{c.last}</dd>"}.join("")
  end

  def form_email_strings arr
    parse_to_comma_sep_emails(arr).split(",").join(",<br />")
  end

  def form_striked_email_strings arr
    arr.present? ? "<br /><span class='tooltip' data-original-title='Dropped due to moderation'>, <del>#{form_email_strings(arr)}</del></span>" : ""
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
    tickets_in_current_page = options[:tickets_in_current_page]
    current_page = options[:current_page]
    per_page = params[:per_page]
    no_of_pages = options[:total_pages]
    no_count_query = no_of_pages.nil?
    if no_count_query
      last_page = tickets_in_current_page==30 ? current_page+1 : current_page
    else
      last_page = no_of_pages
    end
    visible_pages = (full_pagination && !no_count_query) ? visible_page_numbers(options,current_page,no_of_pages) : []
    tooltip = 'tooltip' if !full_pagination

    content = ""
    content << "<div class='toolbar_pagination_full'>" if full_pagination
    if current_page == 1
      content << "<span class='disabled prev_page'>#{options[:previous_label]}</span>"
    else
      content << "<a class='prev_page #{tooltip}' href='/helpdesk/tickets?page=#{(current_page-1)}'
                      title=#{t('previous')}
                      #{shortcut_options('previous') unless full_pagination} >#{options[:previous_label]}</a>"
    end

    unless no_count_query
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
    end

    if current_page == last_page
      content << "<span class='disabled next_page'>#{options[:next_label]}</span>"
    else
      content << "<a class='next_page #{tooltip}' href='/helpdesk/tickets?page=#{(current_page+1)}'
                      rel='next' title=#{t('next')}
                      #{shortcut_options('next') unless full_pagination} >#{options[:next_label]}</a>"
    end
    content << "</div>" if full_pagination
    content
  end

  def remote_note_forward_form options
    content_tag(:div, "",
                :id => options[:id],
                :class => "request_panel note-forward-form hide",
                :rel => "remote",
                "data-remote-url" => options[:path]).html_safe
  end

  def socket_auth_params(connection)
    aes = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    aes.encrypt
    aes.key = Digest::SHA256.digest(NodeConfig[connection]["key"])
    aes.iv  = NodeConfig[connection]["iv"]

    account_data = {
      :account_id => current_user.account_id,
      :user_id    => current_user.id,
      :avatar_url => current_user.avatar_url
    }.to_json
    encoded_data = Base64.encode64(aes.update(account_data)+ aes.final)
    return {:data => encoded_data}.to_json.html_safe
  end

  def latest_note_helper(ticket)
    latest_note_obj = ticket.notes.visible.exclude_source(current_account.helpdesk_sources.note_exclude_sources).newest_first.first
    latest_note_hash = {}
    unless latest_note_obj.nil?
        action_msg = latest_note_obj.fwd_email? ? 'helpdesk.tickets.overlay_forward' : (latest_note_obj.note? ? 'helpdesk.tickets.overlay_note' : 'helpdesk.tickets.overlay_reply')
        latest_note_hash = {
          :user => latest_note_obj.user,
          :created_at => latest_note_obj.created_at,
          :body => latest_note_obj.body,
          :overlay_time => time_ago_in_words(latest_note_obj.created_at),
        }
      else
         action_msg = "helpdesk.tickets.overlay_submitted_#{ticket.tracker_ticket? ? 'tracker' : 'ticket'}"
         latest_note_hash = {
          :user => ticket.requester,
          :created_at => ticket.created_at,
          :body => ticket.description,
          :overlay_time => time_ago_in_words(ticket.created_at),
        }

      end
      latest_note_hash.merge!(:action_msg => t("#{action_msg}"))

      unless ticket.group.nil?
      latest_note_hash.merge!(:ticket_group => ticket.group)
      end

      latest_note_hash
  end

  def agentcollision_alb_socket_host
    "https://#{NodeConfig['socket_host_new']}"
  end

  def autorefresh_alb_socket_host
    "https://#{NodeConfig['socket_autorefresh_host_new']}"
  end

  def agent_collision_index_channel
    AgentCollision.channel(current_account);
  end

  def agent_collision_ticket_view_channel(ticket_id)
    AgentCollision.ticket_view_channel(current_account,ticket_id)
  end

  def agent_collision_ticket_reply_channel(ticket_id)
    AgentCollision.ticket_replying_channel(current_account,ticket_id)
  end

  def agent_collision_ticket_channel(ticket_id)
    AgentCollision.ticket_channel(current_account,ticket_id)
  end

  def facebook_link
    ids = @ticket.fb_post.original_post_id.split('_')
    page_id = @ticket.fb_post.facebook_page.page_id
    if @ticket.fb_post.fb_post?
      "http://www.facebook.com/#{page_id}/posts/#{ids[1]}"
    else
      "http://www.facebook.com/permalink.php?story_fbid=#{ids[0]}&id=#{page_id}&comment_id=#{ids[1]}"
    end
  end

  def freshcaller_audio_dom(notable = nil)
    notable ||= @ticket
    call = notable.freshcaller_call
    dom = ''
    if call.present? && %w[inprogress completed].any? { |status| call.send("recording_#{status}?") }
      dom << tag(:br)
      if call.recording_completed?
        dom << content_tag(:div, content_tag(:div, link_to(I18n.t('freshcaller.ticket.recording.play'), "#{'http://localhost:3004' if Rails.env.development?}/freshcaller_proxy/recording_url?call_id=#{call.fc_call_id}", :type => 'audio/mp3',
                                                           :class => 'call_duration freshcaller', :'data-time' => 0), class: 'ui360'), class: 'freshfoneAudio')
        dom.html_safe
      else
        dom << tag(:br) << content_tag(:div, raw(I18n.t('freshfone.recording_on_process')), class: 'freshfoneAudio_text')
      end
    end
    raw(dom)
  end

  def ticket_body_form form_builder, widget=false, to=false
    contents = []
    email_content = []
    contents << content_tag(:div, (form_builder.text_field :subject, :class => "required text ticket-subject", :placeholder => t('ticket.compose.enter_subject')).html_safe)
    form_builder.fields_for(:ticket_body, @ticket.ticket_body ) do |builder|
      field_value = if (desp = @item.description_html).blank? & (sign = current_user.agent.parsed_signature('ticket' => @ticket, 'helpdesk_name' => @ticket.account.helpdesk_name)).blank?
                      desp.to_s
                    else
                      desp.present? ? (sign.present? ? desp + sign : desp) : ("<p><br /></p>"*2)+sign.to_s
                    end
      email_content << content_tag(:div, (builder.text_area :description_html, :class => "required html_paragraph ta_insert_cr", :"data-wrap-font-family" => true, :value => field_value, :placeholder => "Enter Message...").html_safe)
      email_content << content_tag(:div, render(:partial => "helpdesk/tickets/show/editor_insert_buttons",
                  :locals => {:cntid => 'tkt-cr'}), :class => "request_panel")
      contents <<  content_tag(:div, email_content.join(" ").html_safe, :class => "email-wrapper" )
    end
    contents << content_tag(:div) do
        render :partial => "helpdesk/tickets/ticket_widget/widget_attachment_form", :locals => { :attach_id => "ticket" , :nsc_param => "helpdesk_ticket" , :template => true}
    end
    contents.join(" ").html_safe
  end

  def new_ticket_fields form_builder
    content = []
    current_portal.ticket_fields.each do |field|
      if field.visible_in_view_form?
        field_value = @item[field.field_name] if field.is_default_field? or !params[:topic_id].blank?
        field_label = ( field.is_default_field? ) ? I18n.t("ticket_fields.fields.#{(field.name)}").html_safe : (field.label).html_safe
        content << construct_ticket_element(form_builder, :helpdesk_ticket, field, field_label, field.dom_type, field.required, field_value , "" , false , false)
      end
    end
    content.join(" ").html_safe
  end

  #Helper methods for compose from email drop down starts here
  def options_for_compose
    default_option = [I18n.t("ticket.compose.choose_email"), ""]
    all_options = if current_account.restricted_compose_enabled?
      restricted_options_for_compose
    else
      compose_options(current_account.email_configs.order(:name))
    end
    all_options.unshift(default_option) if all_options.count > 1
    default_select = params[:template_form] && params[:config_emails].present? ? params[:config_emails] : ""

    options_for_select(all_options,default_select)
  end

  def restricted_options_for_compose
    if current_user.can_view_all_tickets?
      compose_options(current_account.email_configs.order(:name))
    elsif (current_user.group_ticket_permission || current_user.assigned_ticket_permission)
      group_ids = current_user.agent_groups.map(&:group_id)
      user_email_configs = current_account.email_configs.where("group_id is NULL or group_id in (?)",group_ids).order(:name)
      compose_options(user_email_configs)
    end
  end

  def compose_options(email_configs)
    if current_account.personalized_email_replies_enabled?
      email_configs.collect{|x| [x.friendly_email_personalize(current_user.name), x.id]}
    else
      email_configs.collect{|x| [x.friendly_email, x.id]}
    end
  end

  def archive_preload_options
    {:archive_notes => [:attachments]}
  end

  #Helper methods for compose from email drop down ends here

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

  def do_spam_check?
    ((current_account.id > get_spam_account_id_threshold) && (current_account.subscription.trial?) && (!ismember?(SPAM_WHITELISTED_ACCOUNTS, current_account.id)))
  end

  def free_admin_email_account?
    Freemail.free?(current_account.admin_email)
  end

  def unique_ticket_recipients(ticket)
    ticket_from_email = get_email_array(ticket.from_email)
    cc_email_hash = ticket.cc_email_hash.nil? ? Helpdesk::Ticket.default_cc_hash : ticket.cc_email_hash

    bcc_emails = get_email_array(cc_email_hash[:bcc_emails])
    cc_emails = get_email_array(cc_email_hash[:cc_emails])
    fwd_emails = get_email_array(cc_email_hash[:fwd_emails])

    total_recipients = bcc_emails.present? ? (cc_emails | fwd_emails | ticket_from_email | bcc_emails) : (cc_emails | fwd_emails | ticket_from_email)
    return total_recipients
  end

  def default_hidden_fields
    ["default_source"]
  end

  # ITIL Related Methods ends here

  def is_invoice_disabled?(installed_app)
    Integrations::Constants::INVOICE_APPS.include?(installed_app.application.name) && !installed_app.configs_invoices.to_s.to_bool
  end

  def ticket_association_box
    links = []
    links << %(<span class="mr12">
                  <b><a href="#" data-placement = "bottomLeft" data-trigger="add_child" class="lnk_tkt_tracker_show_dropdown" id="add_child_tkt"  role="button" data-toggle="popover" data-dropdown="close" data-ticket-id="#{@ticket.display_id}"><span class="tooltip" data-placement= "belowRight" twipsy-content-set="true" data-html="true" data-original-title="#{t('ticket.parent_child.add_child_btn_tooltip')}">#{t('ticket.parent_child.add_child')}</span> </a></b>
                </span>) if Account.current.parent_child_tickets_enabled?
    links << %(<span class="ml12">
                  <b><a href="#" data-placement = "bottomLeft" data-trigger="link_tracker" class="lnk_tkt_tracker_show_dropdown" id="lnk_tkt_tracker"  role="button" data-toggle="popover" data-dropdown="close" data-ticket-id="#{@ticket.display_id}"><span class="tooltip" data-placement= "belowRight" twipsy-content-set="true" data-original-title="#{t('ticket.link_tracker.link_to_tracker_tooltip')}">#{t('ticket.link_tracker.link_to_tracker')}</span> </a></b>
                </span>) if current_account.link_tickets_enabled?
    links.join(links.size > 1 ? '<span class="separator">OR</span>' : '')
    content_tag(:span,
                links.join(links.size > 1 ? '<span class="separator">OR</span>' : '').html_safe,
                :class => "text-center link_ticket_text block p10")
  end

  def tracker_ticket_requester? dom_type
    dom_type.eql?("requester") and (params[:display_ids].present? || @item.tracker_ticket?) and current_account.link_tickets_enabled?
  end

  def show_insert_into_reply?
    privilege?(:reply_ticket) && !(@ticket.twitter? || @ticket.facebook? || @ticket.allow_ecommerce_reply?) && @ticket.from_email.present?
  end

  def collab_ticket_url(ticket_display_id)
    "/helpdesk/tickets/collab/#{ticket_display_id}?collab=true&token=#{Collaboration::Ticket.new(ticket_display_id).access_token}"
  end

  def latest_note_collab_ticket_url(ticket_display_id)
    "/helpdesk/tickets/collab/#{ticket_display_id}/latest_note?token=#{Collaboration::Ticket.new(ticket_display_id).access_token}"
  end

  def sorted_account_skills
    current_account.skill_based_round_robin_enabled? ?
     current_account.skills_trimmed_version_from_cache.collect { |e| [e.name, e.id] } : []
  end

  def has_edit_ticket_skill_privilege?
    current_account.skill_based_round_robin_enabled? && current_user.privilege?(:edit_ticket_skill)
  end

  private

    def ticket_cc_info cc_emails_hash
      CcViewHelper.new(nil, cc_emails_hash[:cc_emails], cc_emails_hash[:dropped_cc_emails]).cc_agent_inline_content.html_safe
    end

end

def to_event_data_scenario(va_rule)
  rule_info = {
    name: va_rule.name,
    description: va_rule.description,
    id: va_rule.id,
    activities: Va::RuleActivityLogger.activities
  }.to_json
end
