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

      @ticket = Helpdesk::Ticket.create({
                  :source => TicketConstants::SOURCE_KEYS_BY_TOKEN[:chat],
                  :status => Helpdesk::Ticketfields::TicketStatus::OPEN,
                  :type   => TicketConstants::TYPE_NAMES_BY_SYMBOL[:lead],
                  :email  => params[:ticket][:email],
                  :description_html => params[:ticket][:content],
                  :subject  => params[:ticket][:subject]
      })

      if @ticket.save
          if create_note
            @status = "success"
            @message = t('freshchat.ticket_success_msg')
            render_result
          else
            @status = "unprocessable_entity"
            @message = t('freshchat.tkt_success_note_error')
            render_result
          end
      else
        @status = "unprocessable_entity"
        @message = t('freshchat.ticket_error_msg')
        render_result
      end

  end  

  def add_note 
    
    if create_note
      @status = "success"
       @message =  t('freshchat.note_success',:display_id => @note.notable.display_id.to_s)
      render_result  
     else
      @status = "unprocessable_entity"
      @message = t('freshchat.note_error')
      render_result
     end

  end

  private
  
  def load_ticket
    @ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
  end

  def create_note 
     @note =  @ticket.notes.create({
                  :private =>false,
                  :user_id =>current_user.id,
                  :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                  :account_id => @ticket.account.id,
                  :body_html => params[:note]})
     @note.save
  end

  def render_result
     respond_to do |format|
            format.json{
               render :json => {:message=> @message, :status => @status}
            }
      end
  end

end
