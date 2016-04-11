module Facebook
  module Core
    class ReplyToComment < Comment
      
      def initialize(fan_page, comment_id, koala_comment = nil)
        super(fan_page, comment_id, koala_comment)
        @type = POST_TYPE[:reply_to_comment]
      end  
      
      # convert_comment - Flag to decide if the comment has to be converted to a fd_item
      # can_dynamo_push - Flag to decide if the comment has to be converted to a ticket or not
      # parent_present  - Set to true when called from a parent class
      def process(convert_comment = false, can_dynamo_push = true, parent_in_dynamo = false)
        convert_post_to_ticket    = false
        push_post_tree_to_dynamo  = parent_in_dynamo ? false : !parent_post_in_dynamo?
        
        #Reply is not converted to a note as yet
        if self.fd_item.nil?
          fb_post    = fd_post_obj(self.koala_comment.parent_post_id) 
          fb_comment = fd_post_obj(self.koala_comment.parent[:id]) if self.koala_comment.parent
          
          #Parent comment is an fd_item
          if fb_comment
            #Parent Comment is a ticket
            self.fd_item = add_as_note(fb_comment.postable, self.koala_comment) if fb_comment.is_ticket?
            #Parent Comment is a note
            self.fd_item = add_as_note(fb_post.postable, self.koala_comment) if fb_comment.is_note?
            
            convert_post_to_ticket = false
          #Parent Post is converted to a ticket, but the parent comment is not added as a note (edge case)
          elsif fb_post
            fetch_and_process_comment(can_dynamo_push)
            can_dynamo_push = false
          else
            convert_post_to_ticket = convert_post?(!push_post_tree_to_dynamo) unless parent_in_dynamo
          end
          
        end
        
        unless parent_in_dynamo
          process_post(convert_post_to_ticket, push_post_tree_to_dynamo) 
          
          #If post is fetched from Dynamo or DB the current note will not be converted to a fd_item         
          if (self.fd_item.nil? && add_as_note?(convert_comment))
            self.fd_item = add_as_note(parent_post.postable, self.koala_comment) 
          end
        end
        
        insert_reply_in_dynamo if (!push_post_tree_to_dynamo && can_dynamo_push)
      end        
      alias :add :process     

      def in_reply_to
        self.koala_comment.parent[:id] if koala_comment.parent
      end
      
      private 
      
      #Post is a ticket but the parent comment is not converted to a note
      def fetch_and_process_comment(can_dynamo_push)
        #Explicitly logging second call made within the exception handler
        self.fan_page.log_api_hits
        Facebook::Core::Comment.new(self.fan_page, in_reply_to).process(true, can_dynamo_push)
      end
      
    end
  end
end
