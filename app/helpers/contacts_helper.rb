module ContactsHelper

	include ContactsCompaniesHelper

  def contact_fields
    current_account.contact_form.contact_fields_from_cache
  end

  def view_contact_fields 
    reject_fields = [:default_name, :default_job_title, :default_company_name, :default_description, :default_tag_names]
    view_contact_fields = contact_fields.reject do |item|
      field_value = (field_value = @user.send(item.name)).blank? ? item.default_value : field_value
      (reject_fields.include? item.field_type) || !field_value.present?
    end
  end

  def render_as_list form_builder, field
    field_value = (field_value = @user.send(field.name)).blank? ? field.default_value : field_value
    if form_builder.nil? 
      show_field field,field_value
    else
      CustomFields::View::DomElement.new(form_builder, :user, :contact, field, field.label, field.dom_type, 
              field.required_for_agent, true, field_value, field.dom_placeholder, field.bottom_note).construct
    end
  end

  def user_activities
    activities = @user_tickets + @user.recent_posts
    activities = activities.sort_by {|item| -item.created_at.to_i}
    activities = activities.take(10)
  end

  def ticket_activity ticket
    icon = content_tag(:span, '', :class => 'ficon-timeline-ticket')
    icon_wrapper = content_tag(:div, icon, :class => 'timeline-icon ticket')

    text = t('contacts.conversations.created_ticket', 
                :ticket_url => helpdesk_ticket_path(ticket.display_id),
                :ticket_subject => ticket.subject).html_safe
    text_wrapper = content_tag(:p, text)

    time_info = t('contacts.conversations.ticket_timeinfo',
                    :time => time_ago_in_words(ticket.created_at),
                    :status => h(ticket.status_name.html_safe)).html_safe
    time_div = content_tag(:p, time_info, :class => 'muted')

    (icon_wrapper + text_wrapper + time_div)
  end

  def forum_activity post
    icon = content_tag(:span, '', :class => 'ficon-timeline-forum')
    icon_wrapper = content_tag(:div, icon, :class => 'timeline-icon forum')

    activity_text = post.original_post? ? 'contacts.conversations.created_forum' : 'contacts.conversations.replied_form'
    text = t(activity_text, 
                :topic_url => discussions_topic_path(post.topic_id),
                :topic_title => post.topic.title).html_safe
    text_wrapper = content_tag(:p, text)

    time_info = t('contacts.conversations.forum_timeinfo',
                    :time => time_ago_in_words(post.created_at),
                    :forum_url => discussions_forum_path(post.forum_id),
                    :forum_title => post.forum.name).html_safe
    time_div = content_tag(:p, time_info, :class => 'muted')

    (icon_wrapper + text_wrapper + time_div)
  end

  def show_field field, field_value
    field_value = I18n.name_for_locale(field_value) if field.field_type == :default_language
    field_value = field_value ? I18n.t('plain_yes') : I18n.t('plain_no') if field.dom_type == :checkbox
    field_value = formated_date field_value, {:format => :short_day_separated,:include_year => true} if field.dom_type == :date
    head = content_tag(:p, field.label, :class => 'field-label ellipsis')
    case field.dom_type
      when :url
        value = content_tag(:a, field_value, :href => field_value, :target => '_blank', :class => 'field-value ellipsis')
      when :phone_number
        value = content_tag(:p, field_value, :class => 'field-value can-make-calls ellipsis', :'data-phone-number' => field_value)
      else
        value = content_tag(:p, field_value, :class => 'field-value ellipsis')
    end
    li = content_tag(:li, (head+value), :class => 'show-field')
  end
end
