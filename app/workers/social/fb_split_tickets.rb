module Social
  class FbSplitTickets < BaseWorker
    
    sidekiq_options :queue => :fb_split_tickets, :retry => 0, :failures => :exhausted
  
    def perform(args)
      @account = Account.current
      @dynamo_helper = Social::Dynamo::Facebook.new
      user     = @account.users.find(args['user_id'])
      user.make_current
      set_notable_objects(args['source_ticket_id'], args['comment_ticket_id'], args['child_fb_post_ids'])
      if @child_fb_notes.present?
        move_notes_to_ticket
        update_ticket_activity
        update_ticket_states
      end
    end
    
    
    def move_notes_to_ticket
      child_post_ids  = @child_fb_notes.map(&:id)
      comment_fb_post = @comment_ticket.fb_post
      
      @account.notes.where([ "id IN (?) and notable_id != ?", @child_fb_notes.map(&:postable_id), @comment_ticket.id ]).update_all_with_publish({ notable_id: @comment_ticket.id }, 
                                  {})
      
      @account.facebook_posts.where(['id IN (?)', child_post_ids]).update_all("ancestry = #{comment_fb_post.id}")
      @child_fb_notes.each do |note|
        note.postable.manual_publish(["create", RabbitMq::Constants::RMQ_ACTIVITIES_NOTE_KEY], [])
      end
    end

    def update_ticket_activity
      @comment_ticket.reload
      activities     = @source_ticket.activities.where(:description => "activities.tickets.conversation.note.long")
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
      outbound_count = @comment_ticket.notes.where(:incoming => false).count
      
      if outbound_count > 0
        @source_ticket.ticket_states.update_attributes({:outbound_count => @source_ticket.outbound_count - outbound_count})
        @comment_ticket.ticket_states.update_attributes({:outbound_count => outbound_count})
      end
    end
    
    def set_notable_objects(source_ticket_id, comment_ticket_id, child_post_ids)
      @source_ticket  = @account.tickets.find_by_id(source_ticket_id)
      @comment_ticket = @account.tickets.find_by_id(comment_ticket_id)  
      @child_fb_notes = @account.facebook_posts.where(:id => child_post_ids)
    end
    
    def update_dynamo_fd_links
      fb_post       = @comment_ticket.fb_post      
      @dynamo_helper.update_ticket_links_in_dynamo(fb_post.post_id, fb_post.facebook_page.default_stream.id)
    end
    
  end
end
