class SubscriptionAdmin::SpamWatchController < ApplicationController

  include AdminControllerMethods
  skip_filter :run_on_slave, :only => [:block_user,:spam_user]

  

  before_filter :load_user, :load_recent_tickets, :load_recent_notes, :only => :spam_details

  def login_from_basic_auth
     #logger.debug "LOGIN FROM BASIC AUTH called in AdminControllerMethods..."
     authenticate_or_request_with_http_basic do |username, password|
       # This has to return true to let the user in
       if Rails.env.production?
          username == 'freshdesk' && Digest::MD5.hexdigest(password) == "6acadd7bf81f9a0ed8ae3a0531f4b824"
       else
          username == 'freshdesk' && password == "USD40$" 
       end
     end
  end

  def spam_details
    render :index
  end

  def block_user
    if params[:user_id]
      User.update_all({:blocked => true, :blocked_at => Time.now}, {:id => params[:user_id]})
      flash[:notice] = "User success fully blocked!"
    end
    redirect_to :back
  end

  def spam_user
    if params[:user_id]
      User.update_all({:deleted => true, :deleted_at => Time.now}, {:id => params[:user_id]})
      flash[:notice] = "User success fully marked as Spam!"
    end
    redirect_to :back
  end

  private

    def load_recent_notes
      @spam_notes = []
      return if "tickets".eql? params["type"]
      notes_query_str = <<-eos
        select note.created_at, note.body_html as 'body_html', note_body.body_html as 'new_body_html' 
        from helpdesk_notes as note
        inner join helpdesk_note_bodies as note_body on note.id = note_body.note_id
        where user_id = #{params[:user_id]} and note.account_id = #{@user.account_id}
        order by note.id desc limit 10
      eos
      @spam_notes =  ActiveRecord::Base.connection.send(:select,notes_query_str)
    end

    def load_recent_tickets
      @spam_tickets = []
      return if "notes".eql? params["type"]
      tickets_query_str = <<-eos
        select ticket.subject, ticket.created_at, ticket_body.description_html as 'new_description_html', 
        ticket.description_html as 'description_html' from helpdesk_tickets as ticket 
        inner join helpdesk_ticket_bodies as ticket_body on ticket.id = ticket_body.ticket_id 
        where requester_id = #{params[:user_id]} and ticket.account_id = #{@user.account_id}
        order by ticket.id desc limit 10
      eos
      @spam_tickets = ActiveRecord::Base.connection.send(:select,tickets_query_str)
    end

    def load_user
      @user = User.find(params[:user_id])
    end
end
