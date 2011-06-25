class Helpdesk::NotesController < ApplicationController
  before_filter { |c| c.requires_permission :manage_tickets }
  before_filter :load_parent_ticket_or_issue
  
  include HelpdeskControllerMethods
  
  def create  
    if @item.save! 
      if params[:post_forums]
        @topic = Topic.find_by_id_and_account_id(@parent.ticket_topic.topic_id,current_account.id)
        if !@topic.locked?
          @post  = @topic.posts.build(:body => params[:helpdesk_note][:body])
          @post.user = current_user
          @post.account_id = current_account.id
          @post.save!
        end
      end
      post_persist
    else
      create_error
    end
  end
  
  def edit
    render :partial => "edit_note"
  end
  
  protected
    def scoper
      @parent.notes
    end

    def item_url
      @parent
    end

    def process_item
      if @parent.is_a? Helpdesk::Ticket      
        send_reply_email if @item.source.eql?(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["email"])
        @parent.responder ||= current_user                     
      end

      if @parent.is_a? Helpdesk::Issue
        unless @item.private
          @parent.tickets.each do |t|
            t.notes << (c = @item.clone)
            Helpdesk::TicketNotifier.deliver_reply(t, c, reply_email)
          end
        end
        @parent.owner ||= current_user  if @parent.respond_to?(:owner)
      end

      @parent.save
    end
    
    def add_cc_email
     if !params[:include_cc].blank? and !params[:cc_emails].blank?
      cc_array = params[:cc_emails].split(',').collect
      cc_array.delete_if {|x| (x == @parent.requester.email or !(valid_email?(x))) }
      @parent.update_attribute(:cc_email,cc_array.uniq)
     end
   end
   
    def valid_email?(email)
       if email=~ /^[a-zA-Z][\w\.-]*[a-zA-Z0-9]@[a-zA-Z0-9][\w\.-]*[a-zA-Z0-9]\.[a-zA-Z][a-zA-Z\.]*[a-zA-Z]$/
        true
      else
        false
      end
    end

    def send_reply_email
      reply_email = params[:reply_email][:id] unless params[:reply_email].nil?
      Helpdesk::TicketNotifier.send_later(:deliver_reply, @parent, @item , reply_email)
      #add_cc_email
      flash[:notice] = t(:'flash.tickets.reply.success')
    end

    def create_error
      redirect_to @parent
    end

end
