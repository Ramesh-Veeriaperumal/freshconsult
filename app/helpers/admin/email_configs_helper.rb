module Admin::EmailConfigsHelper

  def serverProfileoptions 
    Mailbox::MAILBOX_SERVER_PROFILES.map { |m| "<option value='#{m[0]}' data-server='#{m[4]}' data-imap-port='#{m[5]}' data-smtp-port='#{m[6]}' data-smtp-alert='#{m[2]}' #{((@mailbox && (m[0].to_s == @mailbox.selected_server_profile)) ? 'selected' : '')} >#{m[1]}</option>" }
  end
end