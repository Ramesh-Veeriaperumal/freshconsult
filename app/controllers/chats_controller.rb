class ChatsController < ApplicationController
  
  skip_before_filter :check_privilege, :only => [:load]
  before_filter  :load_ticket, :only => [:add_note]

  def load

    @chat = ChatSetting.find_by_display_id(params[:id])
    @app_url = "//#{@chat.account.full_domain}"
    @comm_url = ChatConfig['communication_url'][Rails.env]
    @chat_debug = ChatConfig['chat_debug'][Rails.env]
    @visitor_id = "visitor#{(Time.now.to_f * 1000.0).to_i}"
    
    respond_to do |format|
        format.js
    end

  end

  def create_ticket

    @ticket = current_account.tickets.build(
                  :source => TicketConstants::SOURCE_KEYS_BY_TOKEN[:chat],
                  :email  => params[:ticket][:email],
                  :subject  => params[:ticket][:subject],
                  :requester_name => params[:ticket][:name],
                  :phone => params[:ticket][:phone],
                  :ticket_body_attributes => { :description_html => params[:ticket][:content] }
              ) 

    status = @ticket.save_ticket

    render :json => { :ticket_id=> @ticket.display_id , :status => status }

  end  

  def add_note 
    
    status = create_note
    render :json => { :ticket_id=> @note.notable.display_id , :status => status }

  end

  private
  
  def load_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
  end
  
  def create_note 
    @note = @ticket.notes.build(
                :private => false,
                :user_id => current_user.id,
                :account_id => current_account.id,
                :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                :note_body_attributes => { :body_html => params[:note] }
            )
    @note.save_note
  end

end
