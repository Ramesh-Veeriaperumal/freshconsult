module ContactsCompaniesHelper

  include Helpdesk::TicketsHelperMethods
  include DateHelper
  def contact_tabs(type)
    tabs = [['contacts', t('contacts.title')],
        ['companies', t('company.title')]]
    ul tabs.map{ |t| 
                  link_to t[1], "/#{t[0]}", :id => "#{t[0]}Tab", :class => "#{t[2]}", :'data-pjax' => "#body-container"
                }, { :class => "tabs nav-tabs", :id => "contacts-tab" }, type.eql?('company') ? 1 : 0
  end 

  def ticket_activity ticket, user_page = false
    icon = content_tag(:span, '', :class => 'ficon-timeline-ticket')
    icon_wrapper = content_tag(:div, icon, :class => 'timeline-icon ticket')

    grey_class = ticket.active? ? 'bold-title' : 'muted';
    text = t('contacts.conversations.ticket_subject',
                :ticket_url => ticket_url(ticket),
                :ticket_subject => h("#{ticket.subject} ##{ticket.display_id}"),
                :'data-pjax' => "#body-container",
                :ticket_desc => h(truncate(ticket_desc(ticket), { :length => 350, :omission => "..." }))).html_safe
    text_wrapper = content_tag(:p, text, :class => "break-word timeline-head #{grey_class}")

    sentence_type = user_page ? "user_ticket_timeinfo" : "company_ticket_timeinfo"
    time_info = t('contacts.conversations.' + sentence_type,
                    :user_name => requester(ticket),
                    :time => time_ago_in_words(ticket.created_at),
                    :status => h(ticket.status_name.html_safe),
                    :agent_name => ticket.freshness == :new ? t('none') : h(ticket.responder.display_name),
                    :'data-pjax' => "#body-container").html_safe
    time_div = content_tag(:p, time_info, :class => 'muted')

    (icon_wrapper + text_wrapper + time_div)
  end

  def ticket_desc(ticket)
    if ticket.class.eql?(Helpdesk::Ticket)
      CGI::escapeHTML(ticket.ticket_body.description)
    elsif ticket.class.eql?(Helpdesk::ArchiveTicket)
      CGI::escapeHTML(ticket.description)
    else
      ""
    end
  end

  def ticket_url(ticket)
    ticket.class.eql?(Helpdesk::ArchiveTicket) ? helpdesk_archive_ticket_path(ticket.display_id) :
        helpdesk_ticket_path(ticket.display_id)
  end

  def show_field field, field_value
    field_value = I18n.name_for_locale(field_value) if field.field_type == :default_language
    company_default_dropdown_fields = Company::DEFAULT_DROPDOWN_FIELDS.dup
    field_value = CGI.unescapeHTML(field_value) if company_default_dropdown_fields.push(:custom_dropdown).include?(field.field_type)
    field_value = field_value ? I18n.t('plain_yes') : I18n.t('plain_no') if field.dom_type == :checkbox
    field_value = formatted_date(field_value) if field.dom_type == :date
    field_value = h(field_value).gsub(/\n/, '<br />').html_safe if field.dom_type == :paragraph
    head = content_tag(:p, CGI.unescapeHTML(field.label), :class => 'field-label break-word')
    case field.dom_type
      when :url
        value = content_tag(:a, field_value, :href => field_value, :target => '_blank', :class => 'field-value ellipsis', :rel => 'noreferrer')
      when :phone_number
        value = strange_number?(field_value) ? content_tag(:p,field_value, :class => 'field_value strikethrough') : content_tag(:p, field_value, :class => 'field-value can-make-calls break-word', :'data-phone-number' => field_value,
          :'data-contact-id' => @user.present? ? @user.id : nil,
          :'data-deleted' => @user.present? && @user.deleted)
      else
        value = content_tag(:p, field_value, :class => 'field-value break-word')
    end
    li = content_tag(:li, (head+value), :class => 'show-field')
  end

  def company_description description
    description.gsub(/(\r\n|\n|\r)/, '<br />').html_safe
  end

  def user_companies_limit
    account_additional_settings = Account.current.account_additional_settings
    if account_additional_settings.present?
      (account_additional_settings.additional_settings || {})['extended_user_companies'] || User::MAX_USER_COMPANIES
    else
      User::MAX_USER_COMPANIES
    end
  end
end
