module Social
  class FbSplitTickets < BaseWorker
    
    sidekiq_options :queue => :fb_split_tickets, :retry => 0, :backtrace => true, :failures => :exhausted
  
    def perform(args)
      @account = Account.current
      user     = @account.users.find(args['user_id'])
      user.make_current
      set_notable_objects(args['source_ticket_id'], args['comment_ticket_id'], args['child_fb_post_ids'])
      move_notes_to_ticket
      update_ticket_activity
      update_ticket_states
    end
    
    
    def move_notes_to_ticket
      child_post_ids = @child_fb_notes.map(&:id)
      comment_fb_post = @comment_ticket.fb_post
      
      @account.notes.update_all( "notable_id = #{@comment_ticket.id}", [ "id IN (?)", @child_fb_notes.map(&:postable_id) ] )
      
      @account.facebook_posts.update_all("ancestry = #{comment_fb_post.id}", [ "id IN (?)", child_post_ids ] )
    end

    def update_ticket_activity
      @comment_ticket.reload
      activities = @source_ticket.activities.find(:all, :conditions => 
        {:description => "activities.tickets.conversation.note.long"})    
      child_note_ids = @child_fb_notes.map(&:postable_id)
      
      activities.each do |activity|
        if child_note_ids.include?(activity.note_id)
          activity.activity_data['eval_args']['comment_path'][1]['ticket_id'] = @comment_ticket.display_id
          activity.notable_id = @comment_ticket.id
          activity.save
        end
      end 
    end

    def update_ticket_states
      @comment_ticket.reload
      outbound_count = @comment_ticket.notes.count(:all, :conditions => ["incoming = ?", false])
      
      if outbound_count > 0
        @source_ticket.ticket_states.update_attributes({:outbound_count => @source_ticket.outbound_count - outbound_count})
        @comment_ticket.ticket_states.update_attributes({:outbound_count => outbound_count})
      end
    end
    
    def set_notable_objects(source_ticket_id, comment_ticket_id, child_post_ids)
      @source_ticket    =  @account.tickets.find_by_id(source_ticket_id)
      @comment_ticket   =  @account.tickets.find_by_id(comment_ticket_id)  
      @child_fb_notes   =  @account.facebook_posts.find(:all, :conditions => {:id => child_post_ids})
    end
    
  end
end
