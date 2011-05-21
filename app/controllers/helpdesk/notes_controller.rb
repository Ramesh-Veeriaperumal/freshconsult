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
        add_note if @item.source.eql?(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"])
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

    def send_reply_email
      reply_email = params[:reply_email][:id] unless params[:reply_email].nil?
      Helpdesk::TicketNotifier.send_later(:deliver_reply, @parent, @item , reply_email)
      @parent.create_activity(current_user, 
          "{{user_path}} has sent a {{reply_path}} to the ticket {{notable_path}}", 
          {'eval_args' => {'reply_path' => ['reply_path', {'ticket_id' => @parent.display_id, 
                                                            'comment_id' => @item.id}]}},
          "{{user_path}}has sent a {{reply_path}}") 
                     
      flash[:notice] = "The reply has been sent."
    end
 
    def add_note   
      @parent.create_activity(current_user, 
          "{{user_path}} added a {{comment_path}} to the ticket {{notable_path}}", 
          {'eval_args' => {'comment_path' => ['comment_path', 
                              {'ticket_id' => @parent.display_id, 'comment_id' => @item.id}]}},
          "{{user_path}} added a {{comment_path}}")
    end
 
    def create_error
      redirect_to @parent
    end

end
