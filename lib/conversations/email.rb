module Conversations::Email
  def create_article
    if @kbase_email_exists
      body_html = params[:helpdesk_note][:body_html]
      attachments = params[:helpdesk_note][:attachments]
      Helpdesk::KbaseArticles.create_article_from_note(current_account, current_user, @parent.subject, body_html, attachments)
    end
  end

  def send_reply_email      
    add_cc_email     
    if @item.fwd_email?
      Helpdesk::TicketNotifier.send_later(:deliver_forward, @parent, @item)
      flash[:notice] = t(:'fwd_success_msg')
    else        
      Helpdesk::TicketNotifier.send_later(:deliver_reply, @parent, @item, {:include_cc => params[:include_cc] , 
              :send_survey => ((!params[:send_survey].blank? && params[:send_survey].to_i == 1) ? true : false)})
      flash[:notice] = t(:'flash.tickets.reply.success')
    end
  end

  def add_cc_email
    cc_email_hash_value = @parent.cc_email_hash.nil? ? {:cc_emails => [], :fwd_emails => []} : @parent.cc_email_hash
    if @item.fwd_email?
      fwd_emails = @item.to_emails | @item.cc_emails | @item.bcc_emails | cc_email_hash_value[:fwd_emails]
      fwd_emails.delete_if {|email| (email == @parent.requester.email)}
      cc_email_hash_value[:fwd_emails]  = fwd_emails
    else
      cc_emails = @item.cc_emails | cc_email_hash_value[:cc_emails]
      cc_emails.delete_if {|email| (email == @parent.requester.email)}
      cc_email_hash_value[:cc_emails] = cc_emails
    end
    @parent.update_attribute(:cc_email, cc_email_hash_value)      
  end
    
  def validate_attachment_size
    fetch_item_attachments if @item.fwd_email?
    total_size = (params[nscname][:attachments] || []).collect{|a| a[:resource].size}.sum
    if total_size > Helpdesk::Note::Max_Attachment_Size    
      flash[:notice] = t('helpdesk.tickets.note.attachment_size.exceed')
      redirect_to :back  
    end
  end

  def validate_fwd_to_email
    if(@item.fwd_email? and fetch_valid_emails(params[:helpdesk_note][:to_emails]).blank?)
          flash[:error] = t('validate_fwd_to_email_msg')
          redirect_to item_url
    end
  end

  def check_for_kbase_email
    kbase_email = current_account.kbase_email
    if ((params[:helpdesk_note][:bcc_emails] && params[:helpdesk_note][:bcc_emails].include?(kbase_email)) || 
        (params[:helpdesk_note][:cc_emails] && params[:helpdesk_note][:cc_emails].include?(kbase_email)))
      @item.bcc_emails.delete(kbase_email)
      @item.cc_emails.delete(kbase_email)
      @kbase_email_exists = true
    end
  end
end