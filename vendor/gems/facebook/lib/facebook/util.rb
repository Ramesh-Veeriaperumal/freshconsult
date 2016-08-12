module Facebook
  module Util
  
    def truncate_subject(subject, count)
      (subject.length > count) ? "#{subject[0..(count - 1)]}..." : subject
    end
    
    def get_koala_feed(klass, feed_id)
      koala_obj = ("facebook/koala_wrapper/#{klass}").camelize.constantize.new(@fan_page)
      koala_obj.fetch(feed_id)
      koala_obj
    end
    
    def get_koala_comment(comment)
      koala_comment = Facebook::KoalaWrapper::Comment.new(@fan_page)
      koala_comment.comment = comment
      koala_comment.parse 
      koala_comment
    end
    
    def user_blocked?(user_id)
      Account.current.users.find_by_fb_profile_id(user_id).try(:blocked?)
    end     
    
    #via_comment - When the call to convert a post to a ticket is made by a comment
    def convert_post_to_ticket?(core_obj, via_comment = false) 
      core_obj.fetch_parent_data if via_comment 
      unless social_revamp_enabled?
        if via_comment
          ((core_obj.koala_comment.by_visitor? && core_obj.koala_post.by_company? && core_obj.fan_page.import_company_posts) || (core_obj.koala_post.by_visitor? && core_obj.fan_page.import_visitor_posts)) && !user_blocked?(core_obj.koala_post.requester_fb_id)
        else
          core_obj.koala_post.by_visitor? && core_obj.fan_page.import_visitor_posts && !user_blocked?(core_obj.koala_post.requester_fb_id)
        end
      else
        return false if user_blocked?(core_obj.koala_post.requester_fb_id)
        if via_comment
          core_obj.fan_page.default_ticket_rule.convert_fb_feed_to_ticket?(core_obj.koala_post.by_visitor?, core_obj.koala_post.by_company?, core_obj.koala_comment.by_visitor?)
        else
          core_obj.fan_page.default_ticket_rule.convert_fb_feed_to_ticket?(core_obj.koala_post.by_visitor?) 
        end
      end
    end  
    
    def convert_comment_to_ticket?(core_obj)
      core_obj.fetch_parent_data
      core_obj.fan_page.default_ticket_rule.convert_fb_feed_to_ticket?(false, core_obj.koala_post.by_company?, core_obj.koala_comment.by_visitor?, core_obj.koala_comment.description) && !user_blocked?(core_obj.koala_comment.requester_fb_id)
    end
    
    #Parse the feed content from facebook post
    def html_content_from_feed(feed)
      html_content =  CGI.escapeHTML(feed[:message]) if feed[:message]

      if "video".eql?(feed[:type])
        desc = feed[:description] || ""
        html_content =  "<div class=\"facebook_post\"><a class=\"thumbnail\" href=\"#{feed[:link]}\" target=\"_blank\"><img src=\"#{feed[:picture]}\"></a>
          <div><p><a href=\"#{feed[:link]}\" target=\"_blank\"> #{feed[:name]}</a></p>
          <p><strong>#{html_content}</strong></p>
          <p>#{desc}</p></div></div>"
      elsif "photo".eql?(feed[:type])
        html_content =  "<div class=\"facebook_post\"><p> #{html_content}</p><p><a href=\"#{feed[:link]}\" target=\"_blank\"><img src=\"#{feed[:picture]}\"></a></p></div>"
      elsif "link".eql?(feed[:type])
        link_story   = "<a href=\"#{feed[:link]}\">#{feed[:story]}</a>" if feed[:story]
        html_content =  "<div class=\"facebook_post\"><p> #{html_content}</p><p><#{link_story}</p></div>"
      end
      
      html_content
    end
    
    #Parse the feed content from facebook comment
    def html_content_from_comment(feed)
      html_content =  CGI.escapeHTML(feed[:message]) if feed[:message] 
      return html_content unless feed[:attachment]        
      
      begin
        attachment = feed[:attachment].symbolize_keys!     
        if "share".eql?(attachment[:type])
          desc = feed[:description] || ""
          html_content =  "<div class=\"facebook_post\"><a class=\"thumbnail\" href=\"#{attachment[:target][:url]}\" target=\"_blank\"><img src=\"#{attachment[:media][:image][:src]}\"></a>
            <div><p><a href=\"#{attachment[:url]}\" target=\"_blank\"> #{attachment[:description]}</a></p>
            <p><strong>#{html_content}</strong></p>
            <p>#{desc}</p></div></div>"
        elsif "photo".eql?(attachment[:type])
          html_content =  "<div class=\"facebook_post\"><p> #{html_content}</p><p><a href=\"#{attachment[:target][:url]}\" target=\"_blank\"><img src=\"#{attachment[:media][:image][:src]}\"></a></p></div>"
        end  
      rescue => e
        Rails.logger.debug("Error while parsing attachment in comment:: #{feed[:id]} :: #{feed[:attachment]}")
      end    
      
      html_content
    end
    
    #Parse the feed content from facebook message
    def html_content_from_message(message)
      message = HashWithIndifferentAccess.new(message)
      html_content =  CGI.escapeHTML(message[:message]) if message[:message]

      if message[:attachments]
        if message[:attachments][:data]
          html_content =  "<div class=\"facebook_post\"><p> #{html_content}</p><p>"
          message[:attachments][:data].each do |attachment|
            if attachment[:image_data] && attachment[:image_data][:preview_url] && attachment[:image_data][:url]
              html_content = "#{html_content} <a href=\"#{attachment[:image_data][:url]}\" target=\"_blank\">
                                  <img src=\"#{attachment[:image_data][:preview_url]}\"></a>"
            end
          end
          html_content = "#{html_content} </p></div>"
        end
      end
      html_content
    end

    def new_data_set(data_set)
      message_id_arr   = data_set[:data].collect{|x| x["id"]}
      existing_msg_arr = Account.current.facebook_posts.where(:post_id => message_id_arr).pluck(:post_id)
      data_set[:data].reject{|d| existing_msg_arr.include? d["id"]}
    end
    
    def social_revamp_enabled?
      @social_revamp_enabled ||= Account.current.features?(:social_revamp)
    end
    
  end
end
