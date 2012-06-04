class Support::NotesController < ApplicationController
  def create
    @ticket = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
    raise ActiveRecord::RecordNotFound unless @ticket

    access = (current_user && @ticket.requester_id == current_user.id) || (current_user && current_user.client_manager?  &&@ticket.requester.customer == current_user.customer) || (permission?(:manage_tickets))

    return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless access
  
    @note = @ticket.notes.build({
        "incoming" => true,
        "private" => false,
        "source" => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
        "user_id" => current_user && current_user.id,
        "account_id" => current_account && current_account.id
      }.merge(params[:helpdesk_note]))
    

    if @note.save
      update_cc_list if current_user.client_manager?
      create_attachments
      flash[:notice] = t(:'flash.tickets.notes.create.success')
    else
      flash[:error] = t(:'flash.tickets.notes.create.failure')
    end

    redirect_to :back
  end
  

  def create_attachments 
    return unless @note.respond_to?(:attachments)
    (params[:helpdesk_note][:attachments] || []).each do |a| 
      @note.attachments.create(:content => a[:resource], :description => a[:description], :account_id => @note.account_id)
    end
  end
  
  def update_cc_list
    cc_email_hash_value = @ticket.cc_email_hash
    if cc_email_hash_value.nil?
      cc_email_hash_value = {:cc_emails => [], :fwd_emails => []}
    end
    cc_array = cc_email_hash_value[:cc_emails]
    if(cc_array.is_a?(Array)) # bug fix for string cc_emails value
      cc_array.push(current_user.email)
      cc_array.uniq
      cc_email_hash_value[:cc_emails] = cc_array
      @ticket.update_attribute(:cc_email, cc_email_hash_value)
    end
  end
  
end
