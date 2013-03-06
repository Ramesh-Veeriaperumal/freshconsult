class Support::NotesController < ApplicationController

  skip_before_filter :check_privilege
  before_filter :set_mobile , :only => [:create]

  def create
    @ticket = Helpdesk::Ticket.find_by_param(params[:ticket_id], current_account)
    raise ActiveRecord::RecordNotFound unless @ticket
    access = (current_user && @ticket.requester_id == current_user.id) ||
     (privilege?(:client_manager)  && @ticket.requester.customer == current_user.customer) ||
     (privilege?(:manage_tickets))

    return redirect_to(send(Helpdesk::ACCESS_DENIED_ROUTE)) unless access
  
    @note = @ticket.notes.build({
        "incoming" => true,
        "private" => false,
        "source" => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
        "user_id" => current_user && current_user.id,
        "account_id" => current_account && current_account.id
      }.merge(params[:helpdesk_note]))
    
    build_attachments
    if @note.save
      update_cc_list if privilege?(:client_manager)
      flash[:notice] = t(:'flash.tickets.notes.create.success')
    else
      flash[:error] = t(:'flash.tickets.notes.create.failure')
    end
    respond_to do |format|
      format.html{
        redirect_to :back
      }
      format.mobile {
        render :json => {:success => true,:item => @note}.to_json
      }
    end
  end
  

  def build_attachments 
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
      cc_array.push(current_user.email)
      cc_array.uniq
      cc_email_hash_value[:cc_emails] = cc_array
      @ticket.update_attribute(:cc_email, cc_email_hash_value)
    end
  end
  
end
