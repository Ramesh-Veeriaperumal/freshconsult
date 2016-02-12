module Facebook
  module KoalaWrapper
    module Helper
      
       def post_hash(post_id, type, user_name, user_id, message, created_at)
        post = {
          :id => post_id,
          :type => type,
          :from => {
            :name => user_name,
            :id => user_id
          },
          :message => message,
          :created_time => created_at,
          :shares => {
            :count => 0  
          },
          :comments => {
            :data   => []
          }
        }
      end
    
      def comment_hash(comment_id, type,  user_name, user_id, message, parent, created_at, can_comment)
        comment = {
          :id => comment_id,
          :from => {
            :name => user_name,
            :id => user_id
          },
          :message => message,
          :created_time => created_at,
          :comments => {
            :data   => []
          },
          :can_comment => can_comment
        }
        comment.merge!({:parent => parent}) unless parent.nil?
        comment
      end
      
      def feed_message(fd_item)
        fd_item.is_a?(Helpdesk::Ticket) ? fd_item.description : fd_item.body
      end
      
      def post_from_db(fb_feed)
        fd_item   = fb_feed.postable
        post_hash(fb_feed.post_id, fb_feed.type, fb_feed.user.name, fb_feed.user.fb_profile_id, feed_message(fd_item), "#{Time.at(fd_item.created_at)}")
          
      end
      
      def comment_from_db(fb_feed, can_comment, parent = nil)
        fd_item = fb_feed.postable
        comment = comment_hash(fb_feed.post_id, fb_feed.type, fb_feed.user.name, fb_feed.user.fb_profile_id,
                              feed_message(fd_item), parent, "#{Time.at(fd_item.created_at)}", can_comment)
      end      
      alias :reply_from_db :comment_from_db
      
      
      def post_from_dynamo(fb_feed, type)   
        post_data = JSON.parse(fb_feed["data"][:ss][0]).deep_symbolize_keys
        type = "photo" if post_data[:object_link]
        post = post_hash(post_data[:feed_id], type, post_data[:requester][:name], post_data[:requester][:id], post_data[:description],               post_data[:created_at])
         
        post.merge!({
          :picture => post_data[:object_link],
          :link => "http://www.facebook.com/#{post_data[:feed_id].split('_')[0]}/posts/#{post_data[:feed_id].split('_')[1]}"
        }) unless post_data[:object_link].nil?
        post
      end
      
      def comment_from_dynamo(fb_feed, type, can_comment, parent = nil)   
        comment_data = JSON.parse(fb_feed["data"][:ss][0]).deep_symbolize_keys
        comment = comment_hash(comment_data[:feed_id], type, comment_data[:requester][:name], comment_data[:requester][:id],                      comment_data[:description], parent, comment_data[:created_at], can_comment) 
        
        comment.merge!({
          :attachment => {
            :type => "photo",
            :target => {
              :url => "#"
            },
            :media => {
              :image => {
                :src => comment_data[:object_link]
              }
            }
          }  
        }) unless comment_data[:object_link].nil?
        comment
      end
      alias :reply_from_dynamo :comment_from_dynamo
      
    end
  end
end
