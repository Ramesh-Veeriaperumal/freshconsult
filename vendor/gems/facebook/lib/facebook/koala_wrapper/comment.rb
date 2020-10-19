module Facebook
  module KoalaWrapper
    class Comment < Facebook::KoalaWrapper::Feed

      attr_accessor :feed_id, :feed_type, :description_html, :comments_count, :post_type,
                    :object_link, :parent, :parent_post_id, :can_comment, :message_tags

                 
      alias_attribute :comment,     :feed
      alias_attribute :comment_id,  :feed_id
      alias_attribute :in_reply_to, :parent_post_id
      
      FIELDS  = "#{COMMENT_FIELDS}, comments.fields(#{COMMENT_FIELDS})"
      COMMENT = "comment"
      
      def fetch(comment_id)
        @feed = @rest.get_object(comment_id, :fields => FIELDS)
        parse if @feed
      end

      def parse
        super
        @feed_type         =  @feed[:attachment][:type] if @feed[:attachment]
        @parent            =  @feed[:parent].symbolize_keys! if @feed[:parent]
        @parent_post_id    =  @feed[:object] ? "#{@fan_page.page_id}_#{@feed[:object][:id]}" : 
                                      "#{@fan_page.page_id}_#{@feed[:id].split('_').first}"
        @can_comment       =  @feed[:can_comment]
        @post_type         =  @parent.blank? ? POST_TYPE_CODE[:comment] : POST_TYPE_CODE[:reply_to_comment]

        @object_link       =  @feed[:attachment][:media][:image][:src] if @feed[:attachment] and @feed[:attachment][:media]
        @message_tags      =  @feed[:message_tags]
      end

      #Returns a if the feed type is a post?, video? or status? or link?
      ["photo", "video", "status", "link", "video_inline", "animated_image_video"].each do |object|
        define_method("#{object}?") do
          @feed[:attachment][:type] == POST_TYPE["#{object}".to_sym]
        end
      end

      def type
        COMMENT
      end

      def comment_has_text_excluding_mentions?
        message = @feed[:message].to_s
        if @feed[:message_tags]
          @feed[:message_tags].each do |tags|
            message = message.gsub(tags[:name].to_s, '') if tags.dig(:type) == 'user'
          end
          message = message.gsub(EMOJI_UNICODE_REGEX, '')
          message = message.gsub(Regexp.union(EMOJI_SPECIAL_CHARS_ARRAY), '')
          message = message.gsub(WHITELISTED_SPECIAL_CHARS_REGEX, '')
        end
        message.present?
      end
    end

    def fetch_comment_from_db(comment_id)
      fb_comment  = Account.current.facebook_posts.find_by_post_id(comment_id)
      if fb_comment
        comment   = comment_from_db(fb_comment, true)    
        
        fb_comment.children.each do |fb_reply|
          parent = {:id => comment[:id]}
          comment[:comments][:data] << reply_from_db(fb_reply, false, parent)
        end
        
        self.feed = comment
        parse  
      end
    end
    
    def fetch_comment_from_dynamo(comment_id)
      comment_feeds = dynamo_helper.fetch_feeds(comment_id, @fan_page.default_stream.id)  
      
      fb_comments   = comment_feeds.select{|feed| feed["type"][:ss][0] == POST_TYPE[:comment]}
      fb_replies    = comment_feeds.select{|feed| feed["type"][:ss][0] == POST_TYPE[:reply_to_comment]}
      
      comment       = comment_from_dynamo(fb_comment, POST_TYPE[:comment], true)    
      
      replies.each do |reply|
        parent = {:id => comment[:id]}
        comment[:comments][:data] <<  reply_from_dynamo(reply, POST_TYPE[:reply_to_comment], false, parent)
      end
      comment[:comments][:data] << comment          
      
      self.feed = comment
      parse  
    end
    
  end
end

 
