module Facebook
  module KoalaWrapper
    class Post < Facebook::KoalaWrapper::Feed
        
      attr_accessor :feed_type, :description_html, :shares, :likes, :post_type,
                :object_link, :object_message, :in_reply_to, :can_comment, :parent
                 
      alias_attribute :post,    :feed
      alias_attribute :post_id, :feed_id
      
      FIELDS = "#{POST_FIELDS}, comments.fields(#{COMMENT_FIELDS}, comments.fields(#{COMMENT_FIELDS}))"
      POST   = "feed"

      def initialize(fan_page)
        super(fan_page)
        @can_comment  = true
        @in_reply_to  = nil
      end
      
      def fetch(post_id)
        @feed = @rest.get_object(post_id, :fields => FIELDS)
        parse if @feed
      end

      def parse
        super
        @feed_type         =  @feed[:type]
        @shares            =  @feed[:shares][:count] if @feed[:shares]
        @likes             =  @feed[:likes][:data].count if @feed[:likes]
        @object_link       =  @feed[:picture] 
        @object_message    =  link? ? @feed[:name] : @feed[:story] 
        @post_type         =  POST_TYPE_CODE[:post]
      end
      
      #Returns a if the feed type is a post?, video? or status? or link?
      ["photo", "video", "status", "link", "video_inline", "animated_image_video"].each do |object|
        define_method("#{object}?") do
          @feed[:type] == POST_TYPE["#{object}".to_sym]
        end
      end

      def type
        POST
      end
      
      def fetch_post_from_db(post_id)
        fb_post     = Account.current.facebook_posts.find_by_post_id(post_id)
        if fb_post
          post      = post_from_db(fb_post)    
          
          fb_post.children.each do |fb_comment|
            comment = comment_from_db(fb_comment, true)    
            fb_comment.children.each do |fb_reply|
              parent = {:id => comment[:id]}
              comment[:comments][:data] <<  reply_from_db(fb_reply, false, parent)
            end  
            post[:comments][:data] << comment          
          end
          
          self.feed = post
          parse
        end
      end
      
      def fetch_post_from_dynamo(post_id, dynamo_helper)
        post_feeds    = dynamo_helper.fetch_feeds(post_id, @fan_page.default_stream.id)        
        fb_post       = post_feeds.select{|feed| feed["type"][:ss][0] == POST_TYPE[:post] || feed["type"][:ss][0] == POST_TYPE[:status]}
        fb_comments   = post_feeds.select{|feed| feed["type"][:ss][0] == POST_TYPE[:comment]}
        fb_replies    = post_feeds.select{|feed| feed["type"][:ss][0] == POST_TYPE[:reply_to_comment]}
        
        post          = post_from_dynamo(fb_post[0], POST_TYPE[:comment])    
        
        fb_comments.each do |fb_comment|
          comment = comment_from_dynamo(fb_comment, POST_TYPE[:comment], true)    
          replies = fb_replies.select{|feed| feed["parent_comment"][:ss][0] == fb_comment["feed_id"][:s]}
          replies.each do |reply|
            parent = {:id => comment[:id]}
            comment[:comments][:data] <<  reply_from_dynamo(reply, POST_TYPE[:reply_to_comment], false, parent)
          end
          post[:comments][:data] << comment          
        end
        
        self.feed = post
        parse
      end
    
    end
  end
end

      
        
        
        
