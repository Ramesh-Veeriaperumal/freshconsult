module Admin::EmailConfigsHelper


  def serverProfileoptions
    server_profile = ""
    mailbox = ((@imap_mailbox if @imap_mailbox.id) || @smtp_mailbox)
    server_profile = selected_server_profile_name(mailbox.server_name) if mailbox
  	MailboxConstants::MAILBOX_SERVER_PROFILES.map { |m| "<option value='#{m[0]}' data-server='#{m[4]}' data-imap-port='#{m[5]}' data-smtp-port='#{m[6]}' data-smtp-alert='#{m[2]}' #{((m[0].to_s == server_profile) ? 'selected' : '')} >#{m[1]}</option>" }
  end

  def selected_server_profile_name(server_name)
    return "gmail" unless server_name
    selected_profile = MailboxConstants::MAILBOX_SERVER_PROFILES.select {|server| server_name && (server_name.casecmp("imap.#{server[4]}") == 0 || server_name.casecmp("smtp.#{server[4]}") == 0)}
    selected_profile.first.nil? ?  "other" : selected_profile.first[0].to_s
  end
end