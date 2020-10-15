module Facebook
  module TicketActions
    module Post
      
      include Facebook::TicketActions::Util
      include Facebook::Util
      
      def add_as_ticket(fan_page, koala_feed, ticket_attributes, koala_original_post = nil)
        ticket = nil
        can_comment = koala_feed.can_comment
        
        if koala_feed.description.present? || (koala_feed.photo? || koala_feed.video? || koala_feed.link? || koala_feed.video_inline? || koala_feed.animated_image_video?)
          ticket = @account.tickets.build(
            :subject    => koala_feed.subject,
            :requester  => facebook_user(koala_feed.requester),
            :product_id => ticket_attributes[:product_id],
            :group_id   => ticket_attributes[:group_id] ,
            :source     => Helpdesk::Source::FACEBOOK,
            :created_at => koala_feed.created_at,
            :fb_post_attributes => {
              :post_id          => koala_feed.feed_id,
              :facebook_page_id => fan_page.id,
              :parent_id        => nil,
              :post_attributes  => post_attributes(koala_feed.post_type, can_comment)
            }
          )
          post_html = koala_original_post.present? ? html_content_from_original_post(koala_original_post.feed, ticket) : nil
          description_html = safe_send("html_content_from_#{koala_feed.type}", koala_feed.feed, ticket, post_html)
          ticket.ticket_body_attributes = {
              :description      => koala_feed.description,
              :description_html => description_html
          }
          if ticket.save_ticket
            if !koala_feed.created_at.blank?
              @fan_page.update_attribute(:fetch_since, koala_feed.created_at.to_i)
            end
          else
            puts "error while saving the ticket:: #{ticket.errors.to_json} - #{@account.id} : #{fan_page.page_id} : #{koala_feed.feed_id}"
            ticket = nil
          end
        end
        ticket
      end
      
      def add_as_note(ticket, koala_comment)
        comment_id = koala_comment.comment_id
        note       = @account.facebook_posts.find_by_post_id(comment_id)
        return note if note # TODO what do we do here ? note will already be there in dynamoDB ...
        
        parent_id      = koala_comment.parent.nil? ? koala_comment.parent_post_id : koala_comment.parent[:id]        
        parent_fb_post = @account.facebook_posts.find_by_post_id(parent_id)
        requester      = facebook_user(koala_comment.requester)
        
        unless ticket.blank? || koala_comment.comment.blank?
          @parent_id = ticket
          note = ticket.notes.build(
            :note_body_attributes => {
            },
            :private    => true ,
            :incoming   => true,
            :source     => Helpdesk::Source.note_source_keys_by_token["facebook"],
            :account_id => @fan_page.account_id,
            :user       => requester,
            :created_at => koala_comment.created_at,
            :fb_post_attributes => {
              :post_id          => koala_comment.comment_id,
              :facebook_page_id => @fan_page.id ,
              :parent_id        => parent_fb_post[:id],
              :post_attributes  => post_attributes(koala_comment.post_type, koala_comment.can_comment)
            }
          )

          body_html = safe_send("html_content_from_#{koala_comment.type}", koala_comment.feed, note)
          note.note_body_attributes = {
              :body => koala_comment.description,
              :body_html => body_html
          }
          
          begin
            requester.make_current
            if note.save_note
              if !koala_comment.created_at.blank?
                @fan_page.update_attribute(:fetch_since, koala_comment.created_at.to_i)
              end
              if parent_fb_post.is_note?
                parent_note = parent_fb_post.postable
                parent_note.updated_at = koala_comment.created_at
                parent_note.save
              end
            else
              puts "error while saving the note #{note.errors.to_json} - #{@fan_page.account_id} : #{@fan_page.page_id} : #{koala_comment.comment_id}"
              note = nil
            end
          ensure
            User.reset_current_user
          end
        end
        note
      end
      
      private
      def post_attributes(post_type, can_comment)
        {
          :can_comment => can_comment,
          :post_type   => post_type
        }
      end
      
    end
  end
end
