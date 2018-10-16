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
      
      def ticket_attributes  
        group_id = Account.current.features?(:social_revamp) ? @fan_page.default_stream.ticket_rules.first.group_id :  @fan_page.group_id
        {
          :group_id   => group_id,
          :product_id => @fan_page.product_id
        }
      end  
      
      def facebook_user(profile)
        profile ||= {}
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

      def find_user_with_skipped_messages(messages)
        skip_note_array =Array.new
        return_message = nil
        messages.reverse.each do |message|
          message.symbolize_keys!
          if is_a_page?(message[:from], @fan_page.page_id)
            skip_note_array.push(message[:id])
          else
            return_message = message
            break
          end
        end
        [return_message,skip_note_array]
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
        if reply_sent == :fb_user_blocked
            flash[:notice] = t(:'facebook.facebook_user_blocked')
        elsif reply_sent == :failure
            flash[:notice] = t(:'facebook.error_on_reply_fb')  
        else
            flash[:notice] = t(:'flash.tickets.reply.success') 
        end
      end
 
      
      #send reply to a ticket/note
      def send_reply(fan_page, parent, note, msg_type)
        sandbox {
          @fan_page  = fan_page
          rest       = Koala::Facebook::API.new(fan_page.page_token)
          msg_type == POST_TYPE[:message] ? send_dm(rest, parent, note, fan_page) : send_comment(rest, parent, note)
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
      def send_dm(rest, ticket, note, fan_page)
        thread_identifier  = get_thread_key(fan_page, ticket.fb_post)
        #Real time messages
        if thread_identifier.include? MESSAGE_THREAD_ID_DELIMITER
          page_scoped_user_id = thread_identifier.split(MESSAGE_THREAD_ID_DELIMITER)[1]
          page_token = fan_page.page_token
          message = nil
          begin
            data = {:message => {:text => note.body}, :recipient => {:id => page_scoped_user_id}, :tag => MESSAGE_TAG, :messaging_type => MESSAGE_TYPE}
            message = RestClient.post "#{FACEBOOK_GRAPH_URL}/#{GRAPH_API_VERSION}/me/messages?access_token=#{page_token}", data.to_json, :content_type => :json, :accept => :json
            message = JSON.parse(message)
            message["id"] = "#{FB_MESSAGE_PREFIX}#{message["message_id"]}"
            message.symbolize_keys!
          rescue StandardError => ex
            message = nil
            http_status = ex.try(:http_code)
            ex_response = ex.try(:response)
            if http_status && ex_response
              if valid_json?(ex_response)
                ex_response = JSON.parse(ex_response)
                raise Koala::Facebook::APIError.new(http_status, ex.response) if ex_response['error'] && ex_response['error']['code']
              end
            end
            Rails.logger.error ex.message
            return false
          end
        else
          #Non realtime messages
          message    = rest.put_object(thread_identifier, 'messages', :message => note.body)
          message.symbolize_keys!
        end

        #Create fb_post for this note
        unless message.blank?
          params = {
            :post_id            => message[:id],
            :facebook_page_id   => ticket.fb_post.facebook_page_id,
            :account_id         => ticket.account_id,
            :msg_type           => 'dm'
          }
          thread = if ticket.fb_post.thread_key.present?
            {
              :thread_id        => ticket.fb_post.thread_key,
              :thread_key       => ticket.fb_post.thread_key,
            }
          else
            {
              :thread_id        => ticket.fb_post.thread_id
            }
          end
          note.create_fb_post(params.merge(thread))
        end
      end

      private

      def valid_json?(json)
        begin
          JSON.parse(json)
          return true
        rescue JSON::ParserError => e
          return false
        end
      end

      def get_thread_key(fan_page, fb_post)
        use_thread_key?(fan_page, fb_post) ? fb_post.thread_key : fb_post.thread_id
      end

      def use_thread_key?(fan_page, fb_post)
        fan_page.use_thread_key? || fb_post.thread_key.present?
      end

      def is_a_page?(profile,fan_page_id)
        profile.symbolize_keys!
        profile[:id] == fan_page_id.to_s
      end

    end
  end
end
