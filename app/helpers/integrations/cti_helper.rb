module Integrations::CtiHelper
  include Helpdesk::RequesterWidgetHelper
  def link_call_to_new_ticket(cti_call, sys_converted = true, ticket_subject = nil)
    ticket = cti_create_ticket(cti_call, ticket_subject)
    cti_call.recordable = ticket
    cti_call.status = sys_converted ? Integrations::CtiCall::SYS_CONVERTED : Integrations::CtiCall::AGENT_CONVERTED
    cti_call.save!
  end

  def cti_create_ticket(cti_call, ticket_subject = nil)
    ticket_subject = ticket_subject.present? ? ticket_subject : cti_header_msg(cti_call)
    ticket_desc = cti_header_msg(cti_call)
    ticket_desc += cti_call_url_msg(cti_call)
    ticket_desc += cti_call_info_msg(cti_call)
    ticket = cti_call.account.tickets.build(
      :source => Helpdesk::Source::PHONE,
      :requester_id => cti_call.requester_id,
      :subject  => ticket_subject,
      :responder_id => cti_call.responder_id,
      :ticket_body_attributes => { :description_html => ticket_desc }
    )
    ticket.save_ticket
    ticket
  end

  def cti_header_msg(cti_call)
    I18n.t("integrations.screen_pop.header_msg") % {responder: cti_call.responder.name, requester: (cti_call.requester.name || cti_call.requester.phone || cti_call.requester.mobile) }
  end

  def cti_call_url_msg(cti_call)
    return "<br/><audio controls><source src=\'#{cti_call.options[:call_url]}\' class=\"cti_recording\" /></source></audio>" if cti_call.options[:call_url].present?
    return ""
  end

  def cti_call_info_msg(cti_call)
    call_info = cti_call.options[:call_info]
    return "" if call_info.blank?
    if call_info.is_a? Hash
      msg = "<br/><br/><u><i>" + I18n.t("integrations.screen_pop.call_info") + "</u></i><br/>"
      call_info.each do |key, val|
        msg += "<b>" + key.to_s + "</b> : " + val.to_s + "<br/>"
      end
      return msg
    else
      call_info.to_s
    end
  end

  def create_note(ticket, note_body, user, source, private_note = false)
    note_hash = {
      :private => private_note,
      :user_id => user.id,
      :source => source,
      :account_id => ticket.account.id,
      :note_body_attributes => {
        :body_html => note_body,
      },
    }
    note = ticket.notes.build(note_hash)
    note.save_note
    note
  end

  def requester_namecard_render user
    count = 0
    html = ""
    requester_widget_fields.each do |field|
      value = nil
      if field.class == ContactField && user.safe_send(field.name).present?
        value = user.safe_send(field.name)
      elsif field.class != ContactField && user.company && user.company.safe_send(field.name).present?
        value = user.company.safe_send(field.name)
      end
      count = count + 1 if value.present?
      next if ["name", "job_title"].include?(field.name)
      html << "<div class='cti-caller-more-details hide'>" if count == 4
      html <<  "<div class='cti-caller-field ellipsis'><span class='field-label'>#{field.label}:</span><span class='field-value'>#{value}</span></div>" if value.present?
    end
    html << "</div>" if count > 3
    html
  end

end
