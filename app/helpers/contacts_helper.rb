module ContactsHelper

	include ContactsCompaniesHelper
  include UserEmailsHelper

  def contact_fields
    @user.helpdesk_agent? ? current_account.contact_form.default_contact_fields : current_account.contact_form.contact_fields
  end

  def render_as_list form_builder, field
    field_value = (field_value = @user.send(field.name)).blank? ? field.default_value : field_value
    if form_builder.nil? 
      if field.name == "email" and current_account.features_included?(:contact_merge_ui)
        render_user_email_field field
      else
        show_field field,field_value
      end
    else
      UserEmailsHelper::FreshdeskDomElement.new(form_builder, :user, :contact, field, field.label, field.dom_type, 
              field.required_for_agent, true, field_value, field.dom_placeholder, field.bottom_note, {:account => current_account}).construct
    end
  end

  def view_contact_fields 
    reject_fields = [:default_name, :default_job_title, :default_company_name, :default_description, :default_tag_names]
    view_contact_fields = contact_fields.reject do |item|
      (reject_fields.include? item.field_type) || !(@user.send(item.name).present?)
    end
  end

  def user_activities
    activities = @user_tickets
    activities += @user.recent_posts if current_account.features?(:forums)
    activities = activities.sort_by {|item| -item.created_at.to_i}
    activities = activities.take(10)
  end

  def forum_activity post
    icon = content_tag(:span, '', :class => 'ficon-timeline-forum')
    icon_wrapper = content_tag(:div, icon, :class => 'timeline-icon forum')

    activity_text = post.original_post? ? 'contacts.conversations.created_forum_title' : 'contacts.conversations.replied_forum_title'
    text = t(activity_text, 
                :topic_url => discussions_topic_path(post.topic_id),
                :topic_title => h(post.topic.title)).html_safe
    text_wrapper = content_tag(:p, text, :class => 'break-word timeline-head')

    time_info = t('contacts.conversations.user_forum_timeinfo',
                    :time => time_ago_in_words(post.created_at),
                    :forum_url => discussions_forum_path(post.forum_id),
                    :forum_title => h(post.forum.name)).html_safe
    time_div = content_tag(:p, time_info, :class => 'muted')

    (icon_wrapper + text_wrapper + time_div)
  end

  #This is for user emails display in show page
  #The one for the form is in user_emails_helper

  def render_user_email_field field
    output = []
    output << %(<ul class="user-email-bullet">)
    @user.user_emails.each do |mail|
      output2 = <<HTML
      <p class="primary_email_text">#{h(mail.email)}</p>
HTML
      output3 = <<HTML
      <p class="verify">#{link_to_remote t('contacts.send_activation'), 
    :url => {:controller => "contacts", :id => params[:id], :action => "verify_email", :email_id => mail.id.to_s},
    :method => :put, :loading => "jQuery('[data-verify-id=#{mail.id}]').text('#{t('merge_contacts.please_wait')}').addClass('disabled');", :complete => "jQuery('[data-verify-id=#{mail.id}]').text('#{t('merge_contacts.activate_email')}');", :html => {:id => "verify_email", 'data-verify-id' => mail.id}}</p>
HTML
      output << %(<li>)
      output << content_tag(:span, "", :class => "email-tick #{!mail.primary_role ? "" : "primary"}")
      output << output2 if mail.primary_role
      output << content_tag(:p, "#{h(mail.email)}", :class => (mail.verified ? "" : "helper")) if !mail.primary_role
      output << output3 if !mail.verified and !mail.primary_role
      output << %(</li>)
    end
    output << %(</ul>)
    head = content_tag(:p, field.label, :class => 'field-label break-word')
    output.join("").html_safe
    li = content_tag(:li, (head+output.join("").html_safe), :class => 'show-field')
  end

  def api_permitted_data
    [:id,:name,:email,:created_at,:updated_at,:active,:job_title,
    :phone,:mobile,:twitter_id, :description,:time_zone,:deleted, :helpdesk_agent,
    :fb_profile_id,:external_id,:language,:address,:customer_id]
  end

end
