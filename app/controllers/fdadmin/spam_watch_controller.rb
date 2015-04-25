class Fdadmin::SpamWatchController < Fdadmin::DevopsMainController

	include ReadsToSlave
	
	around_filter :select_shard
	skip_filter :run_on_slave, :only => [:block_user,:spam_user,:hard_block,:internal_whitelist]
	before_filter :load_user,  :only => [:spam_details,:internal_whitelist]
  before_filter :load_recent_tickets, :load_recent_notes, :only => :spam_details

	def spam_details
    result = { :account_name => @account.name ,
               :account_id => @account.id,
               :revenue => @account.subscription.cmrr,
               :state => @account.subscription.state,
               :lifetime_revenue => @account.subscription_payments.sum(:amount),
               :using_acc => @using_account,
               :whitelisted => @user.whitelisted?,
               :spam => @user.spam?,
               :blocked => @user.blocked?,
               :internal_whitelisted => @internal_whitelisted
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
      render :json => {:status => "success"} if User.update_all({:blocked => true, :blocked_at => Time.now}, {:id => params[:user_id]})
    end
	end

	def hard_block
    if params[:user_id]
      render :json => {:status => "success"} if User.update_all({:blocked => true, :blocked_at => "2200-01-01 00:00:00"}, {:id => params[:user_id]})
    end
  end

  def spam_user
    if params[:user_id]
      render :json => {:status => "success"} if User.update_all({:deleted => true, :deleted_at => Time.now}, {:id => params[:user_id]})
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
      all_notes = Helpdesk::Note.find(:all, :conditions => {
                                            :account_id => @user.account_id,
                                            :user_id => @user.id
                                            }, :order => "id desc", :limit => 10)
      all_notes.each_with_index do |note,index|
        @spam_notes[index] = {
          "created_at" => note.created_at,
          "new_body_html" => Helpdesk::NoteOldBody.find_by_account_id_and_note_id(@user.account_id,note.id).body_html
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
          "new_description_html" => Helpdesk::TicketOldBody.find_by_account_id_and_ticket_id(@user.account_id,ticket.id).description_html
        }
      end
    end

    def load_user
      @user = User.find(params[:user_id])
      @account = @user.account
      note_id = Helpdesk::Note.maximum(:id, :conditions => [ "account_id = ? and incoming = 0", @user.account_id ])
      @using_account = !(note_id.blank? or (note_id and Helpdesk::Note.find_by_id(note_id).created_at < 2.months.ago))
      @internal_whitelisted = !WhitelistUser.find_by_user_id(params[:user_id]).blank?
    end

    def select_shard(&block)
      Sharding.run_on_shard(params[:shard_name]) do 
        yield 
      end
    end


end