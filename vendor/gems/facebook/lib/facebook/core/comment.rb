module Facebook  
  module Core   
    class Comment
      
      include Facebook::Util
      include Facebook::Constants
      include Facebook::TicketActions::Post
      include Facebook::TicketActions::Util
      
      include Social::Util
      include Social::Constants
      
      attr_accessor :fan_page, :account, :koala_comment, :source, :type, :fd_item, :koala_post, :dynamo_helper,
                    :parent_fd_item

      alias_attribute :koala_feed, :koala_comment      

      def initialize(fan_page, comment_id, koala_comment = nil)
        @account       = Account.current
        @fan_page      = fan_page
        @koala_comment = koala_comment ? koala_comment : get_koala_feed(POST_TYPE[:comment], comment_id)
        @koala_post    = Facebook::KoalaWrapper::Post.new(fan_page)
        @source        = SOURCE[:facebook]
        @type          = POST_TYPE[:comment]
        @fd_item       = helpdesk_item(@koala_comment.feed_id)
        @dynamo_helper = Social::Dynamo::Facebook.new
      end   
      
      # convert_comment - Flag to decide if the comment has to be converted to a fd_item
      # can_dynamo_push - Flag to decide if the comment has to be converted to a ticket or not
      # parent_present  - Set to true when called from a parent class
      def process(convert_comment = false, can_dynamo_push = true, parent_in_dynamo = false)
        convert_post_to_ticket    = false
        push_post_tree_to_dynamo  = parent_in_dynamo ? false : !parent_post_in_dynamo?
        #Comment is not converted to a fd_item as yet
        if self.fd_item.nil?
          #Comment can be added as a note
          if add_as_note?(convert_comment)
            self.fd_item      = add_as_note(parent_post.postable, self.koala_comment)
          #Comment cannot be converted to a fd_item
          else
            convert_post_to_ticket = convert_post?(!push_post_tree_to_dynamo) unless parent_in_dynamo
          end
        end 
        
        unless parent_in_dynamo
          process_post(convert_post_to_ticket, push_post_tree_to_dynamo) 
          self.fd_item = helpdesk_item(@koala_comment.feed_id)
          
          #If post is fetched from Dynamo or DB the current note will not be converted to a fd_item         
          if (self.fd_item.nil? && add_as_note?(convert_comment))
            self.fd_item = add_as_note(parent_post.postable, self.koala_comment) 
          end
        end
        
        #Comments are pushed to dynamo if its not pushed in via the parent classes already
        dynamo_push_comments = !push_post_tree_to_dynamo && can_dynamo_push
        insert_to_dynamo_and_process_replies(self.fd_item.present?, dynamo_push_comments)
      end
      
      alias :add :process

      def feed_hash
        self.koala_comment.instance_values.symbolize_keys
      end
      
      def feed_id
        self.koala_comment.comment_id
      end
    
      private          
      
      def insert_to_dynamo_and_process_replies(convert_comment, can_dynamo_push)
        insert_comment_in_dynamo if can_dynamo_push
        process_reply_to_comments(convert_comment, can_dynamo_push)  
      end      
      
      def parent_post_in_dynamo?
        return false unless social_revamp_enabled?
        dynamo_helper.has_parent_feed?(Time.now.utc, dynamo_keys, post_id)
      end
      
      def process_post(convert_post, can_dynamo_push)
        fetch_parent_data(!can_dynamo_push) if self.koala_post.feed.blank? 
        post_type  = self.koala_post.by_company? ? POST_TYPE[:status] : POST_TYPE[:post]
        
        core_post  = ("facebook/core/#{post_type}").camelize.constantize.new(self.fan_page, post_id, self.koala_post)
        core_post.process(convert_post, can_dynamo_push)
      end
      
      def process_reply_to_comments(convert, can_dynamo_push)
        self.koala_comment.comments.each do |c|
          reply_to_comment = Facebook::Core::ReplyToComment.new(self.fan_page, nil, get_koala_comment(c))
          reply_to_comment.process(convert, can_dynamo_push, true)
        end
      end     
      
      def parent_post
        self.parent_fd_item ||= fd_post_obj(self.koala_comment.parent_post_id)
      end
      
      def post_id
        self.koala_comment.parent_post_id
      end
      
      def dynamo_keys
        dynamo_hash_and_range_key(self.fan_page.default_stream.id)
      end   
         
      def add_as_note?(convert_comment)
        convert_comment || parent_post.present?
      end
      
      def insert_comment_in_dynamo
        dynamo_helper.insert_comment_in_dynamo(self)
      end 
      
      alias :insert_reply_in_dynamo :insert_comment_in_dynamo
      
      def can_convert_company_post
        self.koala_comment.by_visitor? && self.fan_page.import_company_posts
      end
      
      def can_convert_visitor_post
        self.koala_post.by_visitor? && self.fan_page.import_visitor_posts
      end     
      
      def convert_post?(parent_in_dynamo)
        post_type  = fetch_parent_data(parent_in_dynamo)
        can_convert_company_post || can_convert_visitor_post
      end  
      
      def fetch_parent_data(parent_in_dynamo)
        if parent_in_dynamo
          self.koala_post.fetch_post_from_dynamo(post_id, self.dynamo_helper)
        elsif parent_post.present?
          self.koala_post.fetch_post_from_db(post_id)
        else
          self.koala_post.fetch(post_id)
        end
      end
      
    end    
  end  
end
