module Helpdesk::NoteActions
  
  include ParserUtil

  def conversation_info(note)
    return "" if (note.schema_less_note.nil? or note.to_emails.blank?)
    conv_type = note.fwd_email? ? t("forwarded_to") : (note.outbound_email? ? t("replied_to") : 
      (note.note? ? t("notified_to") : t("to")))
    t("conv_contacts_info", :conv_type_msg => conv_type, 
      :to_emails => parse_to_comma_sep_emails(note.to_emails),
      :cc_emails_key => note.cc_emails.blank? ? "" : t("cc_emails_key", :cc_emails => parse_to_comma_sep_emails(note.cc_emails)),
      :bcc_emails_key => note.bcc_emails.blank? ? "" : t("bcc_emails_key", :bcc_emails => parse_to_comma_sep_emails(note.bcc_emails)))
  end

  def bcc_drop_box_email
    capsule_config = get_app_config('capsule_crm') 
    bcc_drop_box_email = (capsule_config.blank?) ? [] : capsule_config["bcc_drop_box_mail"].split( /,* /).map{|item|[item, item]}
    fixed_bcc = (current_account.bcc_email.blank?) ? [] : current_account.bcc_email.split( /,* /).map{|item|[item, item]}
    bcc_drop_box_email += fixed_bcc
  end

  def conversation_popover_details(note)
    return "" if (note.schema_less_note.nil? or note.to_emails.blank?)
    conv_details = t("conv_contacts_info_pop", :conv_type_msg => t("to"), 
      :to_emails => parse_to_comma_sep_emails(note.to_emails).split(",").join(",<br />"),
      :cc_emails_key => note.cc_emails.blank? ? "" : t("cc_emails_key_pop", :cc_emails => parse_to_comma_sep_emails(note.cc_emails).split(",").join(",<br />")),
      :bcc_emails_key => note.bcc_emails.blank? ? "" : t("bcc_emails_key_pop", :bcc_emails => parse_to_comma_sep_emails(note.bcc_emails).split(",").join(",<br />")))
    content_tag :div, conv_details, :class => "email-details"
  end

end