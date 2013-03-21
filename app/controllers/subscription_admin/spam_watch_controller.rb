class SubscriptionAdmin::SpamWatchController < ApplicationController

  include AdminControllerMethods
  around :read_on_slave, :only => [:block_user,:spam_user]

  

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
        select created_at, body_html from helpdesk_notes 
        where user_id = #{params[:user_id]} and account_id = #{@user.account_id}
        order by id desc limit 10
      eos
      @spam_notes =  ActiveRecord::Base.connection.send(:select,notes_query_str)
    end

    def load_recent_tickets
      @spam_tickets = []
      return if "notes".eql? params["type"]
      tickets_query_str = <<-eos
        select subject,created_at, description_html from helpdesk_tickets 
        where requester_id = #{params[:user_id]} and account_id = #{@user.account_id}
        order by id desc limit 10
      eos
      @spam_tickets = ActiveRecord::Base.connection.send(:select,tickets_query_str)
    end

    def load_user
      @user = User.find(params[:user_id])
    end
end
