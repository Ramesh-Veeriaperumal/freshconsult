module SupportNoteControllerMethods
  include CloudFilesHelper

   def build_attachments 
    attachment_builder(@note, params[:helpdesk_note][:attachments], params[:cloud_file_attachments] )
   end
  
  def update_cc_list
    cc_email_hash_value = @ticket.cc_email_hash
    if cc_email_hash_value.nil?
      cc_email_hash_value = {:cc_emails => [], :fwd_emails => [], :reply_cc => []}
    end
    cc_array = cc_email_hash_value[:cc_emails]
    cc_email_hash_value[:reply_cc] = cc_array.dup unless cc_email_hash_value[:reply_cc]
    if(cc_array.is_a?(Array)) # bug fix for string cc_emails value
      cc_array.push((current_user || @requester).email)
      cc_email_hash_value[:cc_emails] = cc_array.uniq
      cc_email_hash_value[:reply_cc] = cc_email_hash_value[:reply_cc] | ((current_user || @requester).email).to_a
      cc_email_hash_value[:reply_cc].delete_if { |ccs| ccs == @ticket.requester.email }
      @ticket.update_attribute(:cc_email, cc_email_hash_value)
    end
  end
end
