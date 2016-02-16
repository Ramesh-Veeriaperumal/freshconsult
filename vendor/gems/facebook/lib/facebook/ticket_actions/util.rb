module Facebook
  module TicketActions
    module Util
    
      include Facebook::Constants
      include Facebook::Exception::Handler
              
      def helpdesk_item(feed_id)
        fd_post_obj(feed_id).try(:postable)
      end

      def fd_post_obj(feed_id)
        Account.current.facebook_posts.find_by_post_id(feed_id)  
      end      
      
      def facebook_user(profile)
        profile.symbolize_keys!
        profile_id   = profile[:id]
        profile_name = profile[:name]

        user = Account.current.all_users.find_by_fb_profile_id(profile_id)

        unless user
          user = Account.current.contacts.new
          if user.signup!({
              :user => {
                :fb_profile_id  => profile_id,
                :name           => profile_name.blank? ? profile_id : profile_name,
                :active         => true,
                :helpdesk_agent => false
              }
            })
          else
            Rails.logger.debug "unable to save the contact:: #{user.errors.inspect}"
          end
        end
        user
      end
            
      def send_facebook_reply(parent_post_id = nil)
        fb_page     = @parent.fb_post.facebook_page
        parent_post = parent_post_id.blank? ? @parent : @parent.notes.find(parent_post_id)
        reply_sent  = if fb_page
          if @parent.is_fb_message?
            send_reply(fb_page, @parent, @item, POST_TYPE[:message])
          else
            send_reply(fb_page, parent_post, @item, POST_TYPE[:comment])
          end          
        end
        flash[:notice] = reply_sent ? t(:'flash.tickets.reply.success') : t(:'facebook.error_on_reply_fb')
      end  
      
      #send reply to a ticket/note
      def send_reply(fan_page, parent, note, msg_type)
        sandbox {
          @fan_page  = fan_page
          rest       = Koala::Facebook::API.new(fan_page.page_token)
          msg_type == POST_TYPE[:message] ? send_dm(rest, parent, note) : send_comment(rest, parent, note)
        }
      end

      #reply to a comment in fb
      def send_comment(rest, parent, note)
        post_id    = parent.fb_post.original_post_id 
        comment    = rest.put_comment(post_id, note.body)
        comment_id = comment.is_a?(Hash) ? comment["id"] : comment
        post_type  = parent.fb_post.comment? ? POST_TYPE_CODE[:reply_to_comment] : POST_TYPE_CODE[:comment]

        unless comment.blank?
          note.create_fb_post({
            :post_id          => comment_id,
            :facebook_page_id => parent.fb_post.facebook_page_id,
            :account_id       => parent.account_id,
            :parent_id        => parent.fb_post.id,
            :post_attributes  => {
              :can_comment => false,
              :post_type   => post_type
            }
          })
        end
      end
      
      #reply to a message in fb
      def send_dm(rest, ticket, note)
        thread_id  = ticket.fb_post.thread_id
        message    = rest.put_object(thread_id, 'messages', :message => note.body)
        message.symbolize_keys!

        #Create fb_post for this note
        unless message.blank?
          note.create_fb_post({
            :post_id            => message[:id],
            :facebook_page_id   => ticket.fb_post.facebook_page_id,
            :account_id         => ticket.account_id,
            :thread_id          => ticket.fb_post.thread_id,
            :msg_type           => 'dm'
          })
        end
      end
    
    end
  end
end
