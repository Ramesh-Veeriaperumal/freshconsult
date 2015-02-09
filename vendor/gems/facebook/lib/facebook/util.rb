module Facebook::Util
  
  include Gnip::Constants
  include Facebook::Constants
  
  def add_as_ticket(fan_page, koala_feed, real_time_update, convert_args)
    ticket = nil
    can_comment = koala_feed.can_comment
    
    if koala_feed.description.present? || (koala_feed.feed_type == "photo" || koala_feed.feed_type == "video")
      ticket = @account.tickets.build(
        :subject    => koala_feed.subject,
        :requester  => facebook_user(koala_feed.requester),
        :product_id => convert_args[:product_id],
        :group_id   => convert_args[:group_id] ,
        :source     => Helpdesk::Ticket::SOURCE_KEYS_BY_TOKEN[:facebook],
        :created_at => koala_feed.created_at,
        :fb_post_attributes => {
          :post_id          => koala_feed.feed_id,
          :facebook_page_id => fan_page.id,
          :parent_id        => nil,
          :post_attributes  => post_attributes(koala_feed, can_comment)
        },
        :ticket_body_attributes => {
          :description      => koala_feed.description,
          :description_html => koala_feed.description_html
        }
      )
      if ticket.save_ticket
        if real_time_update && !koala_feed.created_at.blank?
          @fan_page.update_attribute(:fetch_since, koala_feed.created_at.to_i)
        end

      else
        puts "error while saving the ticket:: #{ticket.errors.to_json}"
        ticket = nil
      end
    end
    return ticket
  end
  
  def add_as_note(ticket, koala_comment, real_time_update)
    comment_id = koala_comment.comment_id
    note = @account.facebook_posts.find_by_post_id(comment_id)
    return note if note # TODO what do we do here ? note will already be there in dynamoDB ...
    
    parent_id = koala_comment.parent.nil? ? koala_comment.parent_post : koala_comment.parent[:id]
    
    parent_fb_post = @account.facebook_posts.find_by_post_id(parent_id, :select => :id)
    requester = facebook_user(koala_comment.requester)
    
    unless ticket.blank? || koala_comment.comment.blank?
      @parent_id = ticket
      note = ticket.notes.build(
        :note_body_attributes => {
          :body => koala_comment.description,
          :body_html => koala_comment.description_html
        },
        :private    => true ,
        :incoming   => true,
        :source     => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["facebook"],
        :account_id => @fan_page.account_id,
        :user       => requester,
        :created_at => koala_comment.created_at,
        :fb_post_attributes => {
          :post_id          => koala_comment.comment_id,
          :facebook_page_id => @fan_page.id ,
          :parent_id        => parent_fb_post[:id],
          :post_attributes  => {
            :can_comment =>  koala_comment.can_comment,
            :post_type   => koala_comment.post_type
          }
        }
      )
      begin
        requester.make_current
        if note.save_note
          if real_time_update && !koala_comment.created_at.blank?
            @fan_page.update_attribute(:fetch_since, koala_comment.created_at.to_i)
          end
        else
          puts "error while saving the note #{note.errors.to_json}"
          note = nil
        end
      ensure
        User.reset_current_user
      end
    end
    return note
  end
  
  
  private
  def post_attributes(koala_feed, can_comment)
    post_attributes = {
      :can_comment => can_comment,
      :post_type   => koala_feed.post_type  
    }
    post_attributes.merge!({:original_post_id => koala_feed.original_post_id}) unless koala_feed.original_post_id.blank?
    post_attributes
  end
  
end
