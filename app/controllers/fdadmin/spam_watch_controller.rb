class Fdadmin::SpamWatchController < Fdadmin::DevopsMainController

	include ReadsToSlave
  include EmailHelper
	
	around_filter :select_shard
	around_filter :run_on_slave, :only => [:spam_details]
	before_filter :load_user,  :only => [:spam_details,:internal_whitelist]
  before_filter :load_recent_tickets, :load_recent_notes, :only => :spam_details

	def spam_details
    account = @user.account
    result = { :account_name => account.name ,
               :account_id => account.id,
               :revenue => account.subscription.cmrr,
               :state => account.subscription.state,
               :lifetime_revenue => account.subscription_payments.sum(:amount),
               :whitelisted => @user.whitelisted?,
               :spam => @user.spam?,
               :blocked => @user.blocked?,
               :blocked_at => @user.blocked_at,
               :internal_whitelisted => !WhitelistUser.find_by_user_id(params[:user_id]).blank?
             }
    result[:user] = {:name => @user.name , :email => @user.email , :helpdesk_agent => @user.helpdesk_agent}
    result[:ticket] = @spam_tickets
    result[:note] = @spam_notes
    respond_to do |format|
      format.json do 
        render :json => result
      end
    end
	end

	def block_user
		if params[:user_id]
       if User.where({:id => params[:user_id]}).update_all_with_publish({:blocked => true, :blocked_at => Time.now}, {})
        subject = "User #{params[:user_id]} blocked !"
        additional_info = "User blocked from freshops admin"
        notify_account_blocks(nil, subject, additional_info)
        render :json => {:status => "success"}
      end
    end
	end

  def unblock_user
    if params[:user_id]
      render :json => {:status => "success"} if User.where({:id => params[:user_id]}).update_all_with_publish({:blocked => false, :blocked_at => nil}, {})
    end
  end

	def hard_block
    if params[:user_id]
      if User.where({:id => params[:user_id]}).update_all_with_publish({:blocked => true, :blocked_at => "2200-01-01 00:00:00"}, {})
        subject = "User #{params[:user_id]} blocked !"
        additional_info = "User blocked from freshops admin(hard block)"
        notify_account_blocks(nil, subject, additional_info)
        render :json => {:status => "success"}
      end
    end
  end

  def spam_user
    if params[:user_id]
      if User.where({:id => params[:user_id]}).update_all_with_publish({:deleted => true, :deleted_at => Time.now}, {})
        subject = "User #{params[:user_id]} deleted !"
        additional_info = "User deleted from freshops admin"
        notify_account_blocks(nil, subject, additional_info)
        render :json => {:status => "success"}
      end
    end
  end

  def unspam_user
    if params[:user_id]
      render :json => {:status => "success"} if User.where({:id => params[:user_id]}).update_all_with_publish({:deleted => false, :deleted_at => nil}, {})
    end
  end

  def internal_whitelist
  	result = {}
    item = WhitelistUser.new( :user_id => @user.id, :account_id => @user.account_id)
    if item.save
      result[:status] = "success"
    else
      result[:status] = "error"
    end
    respond_to do |format|
    	format.json do 
    		render :json => result
    	end
    end
  end

   private

    def load_recent_notes
      @spam_notes = []
      return if "tickets".eql? params["type"]

      all_notes = Helpdesk::Note.where(account_id: @user.account_id, user_id: @user.id).order('id desc').limit(10)
      all_notes.each_with_index do |note,index|
        @spam_notes[index] = {
          "created_at" => note.created_at,
          "new_body_html" => Helpdesk::NoteBody.where(account_id: @user.account_id, note_id: note.id).first.body_html
        }
      end
    end

    def load_recent_tickets
      @spam_tickets = []
      return if "notes".eql?(params["type"])

      all_tickets = Helpdesk::Ticket.where(account_id: @user.account_id, requester_id: @user.id)
                                    .order('id desc').limit(10)
      all_tickets.each_with_index do |ticket,index|
        @spam_tickets[index] = {
          "subject" => ticket.subject,
          "created_at" => ticket.created_at,
          "new_description_html" => Helpdesk::TicketBody.where(account_id: @user.account_id, ticket_id: ticket.id).first.description_html
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