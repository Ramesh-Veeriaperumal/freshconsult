module SupportNoteControllerMethods

   def build_attachments 
    if @note.respond_to?(:dropboxes) #handle dropbox 
      (params[:dropbox_url] || []).each do |urls|
        decoded_url =  URI.unescape(urls)
        @note.dropboxes.build(:url => decoded_url)
      end
    end
    return unless @note.respond_to?(:attachments)
    (params[:helpdesk_note][:attachments] || []).each do |a| 
      	@note.attachments.build(:content => a[:resource], :description => a[:description], :account_id => @note.account_id)
    end
   end
  
  def update_cc_list
    cc_email_hash_value = @ticket.cc_email_hash
    if cc_email_hash_value.nil?
      cc_email_hash_value = {:cc_emails => [], :fwd_emails => []}
    end
    cc_array = cc_email_hash_value[:cc_emails]
    if(cc_array.is_a?(Array)) # bug fix for string cc_emails value
      cc_array.push((current_user || @requester).email)
      cc_array.uniq
      cc_email_hash_value[:cc_emails] = cc_array
      @ticket.update_attribute(:cc_email, cc_email_hash_value)
    end
  end
end
