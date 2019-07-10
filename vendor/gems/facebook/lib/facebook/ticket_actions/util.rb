require 'net/http'
require 'uri'

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
        profile.symbolize_keys! if profile.respond_to? :symbolize_keys!
        profile_id   = profile[:id]
        profile_name = profile[:name]
        page_id = @fan_page.page_id
        user = fetch_user_from_facebook_mapping(profile_id, page_id)

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
            create_fb_user_mapping(profile_id, page_id, user.id)
          else
            Rails.logger.debug "unable to save the contact:: #{user.errors.inspect}"
          end
        end
        user
      end

      def fetch_user_from_facebook_mapping(profile_id, page_id)
        if page_scope_migration_completed?
          user_mapping = Account.current.fb_user_mappings.find_by_fb_page_id_and_page_scope_id(page_id, profile_id)
        else
          user_mapping = Account.current.fb_user_mappings.find_by_fb_page_id_and_app_scope_id(page_id, profile_id)
          if user_mapping.nil?
            user = Account.current.all_users.find_by_fb_profile_id(profile_id)
            create_fb_user_mapping(profile_id, page_id, user.id) if user.present?
          end
        end
        user_id = user_mapping.try(:user_id)
        user = Account.current.all_users.find_by_id(user_id) if user_id.present?
        user
      end

      def create_fb_user_mapping(profile_id, page_id, user_id)
        if page_scope_migration_completed?
          params = { fb_page_id: page_id, page_scope_id: profile_id, user_id: user_id }
        else
          page_scope_id = fetch_page_scope_id(profile_id)
          params = { fb_page_id: page_id, page_scope_id: page_scope_id, app_scope_id: profile_id, user_id: user_id }
        end
        if params[:page_scope_id].present?
          fb_user_mapping = Account.current.fb_user_mappings.new(params)
          fb_user_mapping.save!
        end
      end

      def page_scope_migration_completed?
        Account.current.facebook_page_scope_migration_enabled?
      end

      def fetch_page_scope_id(app_scope_id)
        limit = 0
        begin
          client_id, client_secret = Facebook::Tokens.new(false).tokens.values
          mac = OpenSSL::HMAC.hexdigest("SHA256", client_secret, @fan_page.page_token)
          uri = URI.parse("#{FACEBOOK_GRAPH_URL}/#{GRAPH_API_VERSION}/#{PAGE_SCOPE_URL}")
          request = Net::HTTP::Post.new(uri)
          req_options = {
            use_ssl: uri.scheme == "https",
          }
          request.body = "user_ids=#{app_scope_id}&appsecret_proof=#{mac}&access_token=#{@fan_page.page_token}"
          response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
            http.request(request)
          end
          response_body = JSON.parse(response.body)
          raise "error in fetching page scope id -> #{response_body}" if response_body["error"] && response_body["error"]["code"] < 200
          response_body[app_scope_id]
        rescue => e
          Rails.logger.error("Error in fetching the page scope ID for account_id :: #{Account.current.id} :: page_id :: #{@fan_page.page_id} :: app scope id :: #{app_scope_id} :: #{e.message} :: #{e.backtrace}")
          limit += 1
          retry if limit < 3
        end
      end

      def first_customer_message(messages)
        skip_note_array =Array.new
        return_message = nil
        messages.reverse.each do |message|
          if is_a_page?(message[:from], @fan_page.page_id)
            skip_note_array.push(message[:id])
          else
            return_message = message
            break
          end
        end
        [return_message, skip_note_array]
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

      def update_facebook_errors_in_schemaless_notes(error, note_id)        
        schema_less_notes = Account.current.schema_less_notes.find_by_note_id(note_id)
        schema_less_notes.note_properties[:errors] ||= {}
        fb_errors = { facebook: { error_code: error[:code], error_message: error[:message] } }
        schema_less_notes.note_properties[:errors].merge!(fb_errors)
        schema_less_notes.save!
      end
      
      #send reply to a ticket/note
      def send_reply(fan_page, parent, note, msg_type)
        error_msg, return_value, error_code = sandbox do
          @fan_page  = fan_page
          rest       = Koala::Facebook::API.new(fan_page.page_token)
          msg_type == POST_TYPE[:message] ? send_dm(rest, parent, note, fan_page) : send_comment(rest, parent, note)
        end
        update_facebook_errors_in_schemaless_notes({ code: error_code, message: error_msg }, @item.id) if error_msg.present? || error_code.present?
        return_value
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
        profile[:id] == fan_page_id.to_s
      end

    end
  end
end
