module Facebook
  module Core
    class ReplyToComment < Comment
      
      def initialize(fan_page, comment_id, koala_comment = nil)
        super(fan_page, comment_id, koala_comment)
        @type = POST_TYPE[:reply_to_comment]
      end  
      

      def process(force_convert = false)
        #Reply is not converted to a note as yet
        if self.fd_item.nil?
          fb_post    = fd_post_obj(self.koala_comment.parent_post_id) 
          fb_comment = fd_post_obj(in_reply_to) if self.koala_comment.parent
          
          #Parent comment is an fd_item
          if fb_comment
            #Parent Comment is a ticket
            self.fd_item = add_as_note(fb_comment.postable, self.koala_comment) if fb_comment.is_ticket?
            #Parent Comment is a note
            self.fd_item = add_as_note(fb_post.postable, self.koala_comment) if fb_comment.is_note?
            
          #Parent Post is converted to a ticket, but the parent comment is not added as a note (edge case)
          elsif fb_post
            fetch_and_process_comment(fb_post)
          #Case to convert a post to a ticket via a comment happens only when it's a visitor comment  
          elsif convert_post_to_ticket?(self, true)
            process_post
          end
        end
        
      end        
      
      alias :add :process     

      def in_reply_to
        self.koala_comment.parent[:id] if koala_comment.parent
      end
      
      private 
      
      #Post is a ticket but the parent comment is not converted to a note
      def fetch_and_process_comment(fb_post)
        #Explicitly logging second call made within the exception handler
        self.fan_page.log_api_hits
        Facebook::Core::Comment.new(self.fan_page, in_reply_to).process(fb_post.postable)
      end
      
    end
  end
end
