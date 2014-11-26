class SubscriptionAdmin::SpamWatchController < ApplicationController

  include AdminControllerMethods
  include ReadsToSlave
  around_filter :select_shard
  skip_filter :run_on_slave, :only => [:block_user,:spam_user,:hard_block,:internal_whitelist]

  

  before_filter :load_user,  :only => [:spam_details,:internal_whitelist]
  before_filter :load_recent_tickets, :load_recent_notes, :only => :spam_details


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
  
  def hard_block
    if params[:user_id]
      User.update_all({:blocked => true, :blocked_at => "2200-01-01 00:00:00"}, {:id => params[:user_id]})
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

  def internal_whitelist
    item = WhitelistUser.new( :user_id => @user.id, :account_id => @user.account_id)
    if item.save
      flash[:notice] = "User ID #{params[:user_id]}  Whitelisted"
      redirect_to :back
    else
      flash[:notice] = "Adding Whitelisted User ID Failed"
      redirect_to :back
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

    def check_admin_user_privilege
      if !(current_user and  current_user.has_role?(:manage_admin))
        flash[:notice] = "You dont have access to view this page"
        redirect_to(admin_subscription_login_path)
      end
    end 
end
