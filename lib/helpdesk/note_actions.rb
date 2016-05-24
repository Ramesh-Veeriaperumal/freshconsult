module Helpdesk::NoteActions
  
  include ParserUtil

  def conversation_info(note)
    return "" if (note.schema_less_note.nil? or note.to_emails.blank?)
    conv_type = note.fwd_email? ? t("forwarded_to") : ((note.outbound_email? || note.reply_to_forward?) ? t("replied_to") : 
      (note.note? ? t("notified_to") : t("to")))
    t("conv_contacts_info", :conv_type_msg => conv_type, 
      :to_emails => parse_to_comma_sep_emails(note.to_emails),
      :cc_emails_key => cc_conversation_info(note),
      :bcc_emails_key => note.bcc_emails.blank? ? "" : t("bcc_emails_key", :bcc_emails => parse_to_comma_sep_emails(note.bcc_emails)))
  end

  def bcc_drop_box_email
    capsule_config = get_app_config('capsule_crm') 
    bcc_drop_box_email = (capsule_config.blank?) ? [] : capsule_config["bcc_drop_box_mail"].split( /,* /)
    fixed_bcc = (current_account.bcc_email.blank?) ? [] : current_account.bcc_email.split( /,* /)
    bcc_drop_box_email += fixed_bcc
  end

  def conversation_popover_details(note)
    return "" if (note.schema_less_note.nil? or note.to_emails.blank?)
    content_tag :div, (content_tag :dl, conv_details(note).html_safe), :class => "email-details"
  end

  def conv_details note
    cc_emails_string = ""
    if note.cc_emails_hash[:cc_emails].present? || note.cc_emails_hash[:dropped_cc_emails].present?
      cc_emails_helper = CcViewHelper.new(nil, note.cc_emails_hash[:cc_emails], note.cc_emails_hash[:dropped_cc_emails])
      cc_emails_string = cc_emails_helper.cc_agent_hover_content
    end
    conv_array = []
    conv_array << [t('Subject'), note.subject] unless note.subject.blank?
    conv_array << [t('to'), generate_email_strings(note.to_emails)]
    conv_array << [t('helpdesk.shared.cc'), cc_emails_string] if cc_emails_string.present?
    conv_array << [t('helpdesk.shared.bcc'), generate_email_strings(note.bcc_emails)] unless note.bcc_emails.blank?
    conv_array.map{|c| "<dt>#{c.first} : </dt><dd>#{c.last}</dd>"}.join("")
  end

  def generate_email_strings arr
    parse_to_comma_sep_emails(arr).split(",").join(",<br />")
  end

  def to_event_data(item)
    hash = JSON.parse(item.to_json)
    hash['note']['kind'] = item.kind
    hash['note']['to'] = item.schema_less_note.to_emails
    hash.to_json
  end

  private

    def cc_conversation_info(note)
      return "" if note.cc_emails_hash[:cc_emails].blank? && note.cc_emails_hash[:dropped_cc_emails].blank?
      cc_emails_helper = CcViewHelper.new(nil, note.cc_emails_hash[:cc_emails], note.cc_emails_hash[:dropped_cc_emails])
      cc_emails_string = cc_emails_helper.cc_agent_inline_content
      t("cc_emails_key", :cc_emails => cc_emails_string)
    end

end