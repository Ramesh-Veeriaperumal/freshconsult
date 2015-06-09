module Conversations::Email
  def create_article
    body_html = params[:helpdesk_note][:note_body_attributes][:full_text_html]
    attachments = params[:helpdesk_note][:attachments]
    Helpdesk::KbaseArticles.create_article_from_note(current_account, current_user, @parent.subject, body_html, attachments)
  end

  def send_email #possible dead code
    add_cc_email     
    if @item.fwd_email?
      Helpdesk::TicketNotifier.send_later(:deliver_forward, @parent, @item)
      flash[:notice] = t(:'fwd_success_msg')
    else        
      Helpdesk::TicketNotifier.send_later(:deliver_reply, @parent, @item, {:include_cc => params[:include_cc] ,
              :send_survey => ((!params[:send_survey].blank? && params[:send_survey].to_i == 1) ? true : false)})
      flash[:notice] =  (@publish_solution == false) ?
        t(:'flash.tickets.reply.without_kbase') : t(:'flash.tickets.reply.success')
    end
  end

  def add_cc_email #possible dead code
    cc_email_hash_value = @parent.cc_email_hash.nil? ? {:cc_emails => [], :fwd_emails => [], :reply_cc => []} : @parent.cc_email_hash
    if @item.fwd_email?
      fwd_emails = @item.to_emails | @item.cc_emails | @item.bcc_emails | cc_email_hash_value[:fwd_emails]
      fwd_emails.delete_if {|email| (email == @parent.requester.email)}
      cc_email_hash_value[:fwd_emails]  = fwd_emails
    else
      cc_email_hash_value[:reply_cc] = @item.cc_emails.reject {|email| (email == @parent.requester.email)}
      cc_emails = @item.cc_emails | cc_email_hash_value[:cc_emails]
      cc_emails.delete_if {|email| (email == @parent.requester.email)}
      cc_email_hash_value[:cc_emails] = cc_emails
    end
    @parent.update_attribute(:cc_email, cc_email_hash_value)      
  end

  def validate_fwd_to_email
    if(@item.fwd_email? and fetch_valid_emails(params[:helpdesk_note][:to_emails]).blank?)
          flash[:error] = t('validate_fwd_to_email_msg')
          redirect_to item_url
    end
  end

  def check_for_kbase_email
    kbase_email = current_account.kbase_email
    if (params[:helpdesk_note].slice(*[:to_emails, :cc_emails, :bcc_emails]).values.flatten.include?(kbase_email))
      @item.bcc_emails.delete(kbase_email)
      @item.cc_emails.delete(kbase_email)
      @publish_solution = privilege?(:publish_solution) 
    end
  end
end