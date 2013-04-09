class Public::NotesController < ApplicationController

  include ParserUtil
  include SupportNoteControllerMethods
  
  skip_before_filter :check_privilege
  before_filter :set_mobile , :only => [:create]

  def create
    schema_less_ticket = current_account.schema_less_tickets.find_by_access_token(params[:ticket_id])
    @ticket = schema_less_ticket.ticket
    raise ActiveRecord::RecordNotFound unless @ticket

    unless current_user
      unless can_add_note?(params[:requester_email])
         flash[:error] = t(:'flash.tickets.notes.create.invalid_email')
         return redirect_to :back
      end
    end

    @note = @ticket.notes.build({
          "incoming" => true,
          "private" => false,
          "source" => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
          "user_id" => (current_user && current_user.id) || (@requester && @requester.id),
          "account_id" => current_account && current_account.id
        }.merge(params[:helpdesk_note]))

    build_attachments
    if @note.save
      update_cc_list if (current_user || @requester).client_manager?
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
  
  
  private

    def can_add_note?(email)
      @requester = current_account.all_users.find_by_email(email)
      return true if @requester && @requester.id == @ticket.requester_id  # return if requester had added note
      get_cc_email
      @cc_parsed_array.each do |cc_parsed|
        if cc_parsed[:email].include?(email)    #check if cc has added a note
          unless @requester
            @requester = current_account.users.new #create an account for cc if not created
            @requester.signup!({:user => {
                                :email => email, 
                                :user_role => User::USER_ROLES_KEYS_BY_TOKEN[:customer]}},current_portal)
          end
          return true # cc has added
        end
      end
      return false     #  not an cc or not a requester or not a valid user    
    end

    def get_cc_email
      cc_email_hash_value = @ticket.cc_email_hash
      if cc_email_hash_value
        cc_array =  cc_email_hash_value[:cc_emails] 
        @cc_parsed_array = []
        cc_array.each do |cc|
          @cc_parsed_array <<  parse_email_text(cc)
        end
      end
    end

end
