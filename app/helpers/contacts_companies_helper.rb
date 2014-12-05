module ContactsCompaniesHelper

  include Helpdesk::TicketsHelperMethods
  def contact_tabs(type)
    tabs = [['contacts', t('contacts.title')],
        ['customers', t('company.title')]]
    ul tabs.map{ |t| 
                  link_to t[1], "/#{t[0]}", :id => "#{t[0]}Tab", :class => "#{t[2]}"
                }, { :class => "tabs nav-tabs", :id => "contacts-tab" }, type.eql?('user') ? 0 : 1
  end 

  def ticket_activity ticket, user_page = false
    icon = content_tag(:span, '', :class => 'ficon-timeline-ticket')
    icon_wrapper = content_tag(:div, icon, :class => 'timeline-icon ticket')

    grey_class = ticket.active? ? 'bold-title' : 'muted';
    text = t('contacts.conversations.ticket_subject',
                :ticket_url => helpdesk_ticket_path(ticket.display_id),
                :ticket_subject => ticket.subject.blank? ? "##{ticket.display_id}" : h(ticket.subject)).html_safe
    text_wrapper = content_tag(:p, text, :class => "break-word timeline-head #{grey_class}")

    sentence_type = user_page ? "user_ticket_timeinfo" : "company_ticket_timeinfo"
    time_info = t('contacts.conversations.' + sentence_type,
                    :user_name => requester(ticket),
                    :time => time_ago_in_words(ticket.created_at),
                    :status => h(ticket.status_name.html_safe),
                    :agent_name => ticket.freshness == :new ? t('none') : h(ticket.responder.display_name)).html_safe
    time_div = content_tag(:p, time_info, :class => 'muted')

    (icon_wrapper + text_wrapper + time_div)
  end

  def show_field field, field_value
    field_value = I18n.name_for_locale(field_value) if field.field_type == :default_language
    field_value = field_value ? I18n.t('plain_yes') : I18n.t('plain_no') if field.dom_type == :checkbox
    field_value = formated_date field_value, {:format => :short_day_separated,:include_year => true} if field.dom_type == :date
    field_value = h(field_value).gsub(/\n/, '<br />').html_safe if field.dom_type == :paragraph
    head = content_tag(:p, CGI.unescapeHTML(field.label), :class => 'field-label break-word')
    case field.dom_type
      when :url
        value = content_tag(:a, field_value, :href => field_value, :target => '_blank', :class => 'field-value ellipsis')
      when :phone_number
        value = content_tag(:p, field_value, :class => 'field-value can-make-calls break-word', :'data-phone-number' => field_value)
      else
        value = content_tag(:p, field_value, :class => 'field-value break-word')
    end
    li = content_tag(:li, (head+value), :class => 'show-field')
  end
end