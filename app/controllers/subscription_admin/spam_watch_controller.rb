class SubscriptionAdmin::SpamWatchController < ApplicationController

  include AdminControllerMethods
  include ReadsToSlave
  around_filter :select_shard
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
      all_notes = Helpdesk::Note.find(:all, :conditions => {
                                            :account_id => @user.account_id,
                                            :user_id => @user.id
                                            }, :order => "id desc", :limit => 10)
      all_notes.each_with_index do |note,index|
        @spam_notes[index] = {
          "created_at" => note.created_at,
          "new_body_html" => note.read_from_riak.body_html
        }
      end
    end

    def load_recent_tickets
      @spam_tickets = []
      return if "notes".eql?(params["type"])
      all_tickets = Helpdesk::Ticket.find(:all, :conditions => {
                                                :account_id => @user.account_id, 
                                                :requester_id => @user.id
                                                }, :order => "id desc" ,:limit => 10)
      all_tickets.each_with_index do |ticket,index|
        @spam_tickets[index] = {
          "subject" => ticket.subject,
          "created_at" => ticket.created_at,
          "new_description_html" => ticket.read_from_riak.description_html
        }
      end
    end

    def load_user
      @user = User.find(params[:user_id])
    end

    def select_shard(&block)
      Sharding.run_on_shard(params[:shard_name]) do 
        yield 
      end
    end
end
