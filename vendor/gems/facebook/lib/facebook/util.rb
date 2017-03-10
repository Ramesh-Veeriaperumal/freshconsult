module Facebook
  module Util

    include Facebook::Constants

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
    def html_content_from_feed(feed, item)
      html_content =  CGI.escapeHTML(feed[:message]) if feed[:message]
      if "video".eql?(feed[:type])
        desc = feed[:description] || ""
        thumbnail, inline_attachment = create_inline_attachment_and_get_url(feed[:picture], item, 0)
        html_content = FEED_VIDEO % { :target_url => feed[:link], :thumbnail => thumbnail, 
          :att_url => feed[:link], :name => feed[:name], :html_content => html_content, :desc => desc }

      elsif "photo".eql?(feed[:type])
        photo_url, inline_attachment = create_inline_attachment_and_get_url(feed[:picture], item, 0)
        html_content = FEED_PHOTO % { :html_content => html_content, :link => feed[:link],
         :photo_url => photo_url, :height => "" }
      elsif "link".eql?(feed[:type])
        link_story   = "<a href=\"#{feed[:link]}\">#{feed[:name]}</a>" if feed[:name]
        html_content = FEED_LINK % {:html_content => html_content, :link_story => link_story}
      end
      inline_attachment = nil unless attachment_present?(inline_attachment)
      item.inline_attachments = [inline_attachment].compact
      html_content
    end
    
    #Parse the feed content from facebook comment
    def html_content_from_comment(feed, item)
      html_content =  CGI.escapeHTML(feed[:message]) if feed[:message] 
      return html_content unless feed[:attachment]        
      
      begin
        attachment = feed[:attachment].symbolize_keys!     
        if "share".eql?(attachment[:type])
          desc = feed[:description] || ""
          link_story   = "<a href=\"#{attachment[:url]}\">#{attachment[:title]}</a>" if attachment[:title]
          html_content = COMMENT_SHARE % {:html_content => html_content, :link_story => link_story}
        elsif ["photo","sticker"].include?(attachment[:type])
          height = attachment[:type] == "sticker" ? "200px" : ""
          photo_url, inline_attachment = create_inline_attachment_and_get_url(attachment[:media][:image][:src], item, 0)
          html_content = COMMENT_PHOTO % { :html_content => html_content, :link => attachment[:target][:url],
           :photo_url => photo_url, :height => height }
        end
      rescue => e
        Rails.logger.debug("Error while parsing attachment in comment:: #{feed[:id]} :: #{feed[:attachment]}")
      end
      inline_attachment = nil unless attachment_present?(inline_attachment)
      item.inline_attachments = [inline_attachment].compact   
      html_content
    end
    
    #Parse the feed content from facebook message
    def html_content_from_message(message, item)
      message = HashWithIndifferentAccess.new(message)
      html_content =  CGI.escapeHTML(message[:message]) if message[:message]
      inline_attachments = []
      content_objects = []
      if message[:attachments]
        if message[:attachments][:data]
          html_content =  "<div class=\"facebook_post\"><p> #{html_content}</p><p>"
          message[:attachments][:data].each_with_index do |attachment, i|

            type = attachment_type(attachment)
            if type.present?
              if [:image].include? type
                url = attachment[URL_PATHS[:message][type]][:url]
                attached_url, inline_attachment = create_inline_attachment_and_get_url(url, item, i)
                inline_attachments.push(inline_attachment) if attachment_present?(inline_attachment)                 
 
                html_content = MESSAGE_IMAGE % {:html_content => html_content, :url => attached_url,
                 :height => "300px" }
              else
                url = (attachment[:video_data].present?) ? attachment[:video_data][:url] : attachment[:file_url]
                content_objects << get_options(url, attachment)
              end
            end
          end
          build_normal_attachments(item, content_objects)
          html_content = "#{html_content} </p></div>"
        end
      elsif message[:shares] #### for stickers 
        if message[:shares][:data]
          html_content =  "<div class=\"facebook_post\"><p> #{html_content}</p><p>"
          message[:shares][:data].each_with_index do |share, i|
            if share[:link]
              url = share[:link]
              stickers_url, inline_attachment = create_inline_attachment_and_get_url(url, item, i)
              inline_attachments.push(inline_attachment) if attachment_present?(inline_attachment)
              
              html_content = MESSAGE_SHARE % {:html_content => html_content, :url => stickers_url,
               :height => "200px"}
            end
          end
          html_content = "#{html_content} </p></div>"
        end
      end
      item.inline_attachments = inline_attachments.compact
      html_content
    end

    def create_inline_attachment_and_get_url url, item, i
      options = get_options(url)
      inline_attachment = create_inline_attachment(item, i, options)
      attached_url = attachment_url inline_attachment, url
      [attached_url, inline_attachment]
    end

    def attachment_present? attachment
      attachment.try :id
    end

    def attachment_type attachment
      if attachment[:image_data] and attachment[:image_data][:preview_url] and attachment[:image_data][:url]
        :image
      elsif attachment[:video_data] and attachment[:video_data][:preview_url] and attachment[:video_data][:url]
        :video
      elsif attachment[:file_url] and attachment[:name]
        :file
      else
        nil  
      end
    end

    def get_options(url, attachment_params = {})
      file = open(url)
      file_name = attachment_params[:name] || url.split(URL_DELIMITER).first[url.rindex(URL_PATH_DELIMITER)+1, url.length]
      content_type = file_name.split(FILENAME_DELIMITER).last
      {
        :file_content => file,
        :filename     => file_name,
        :content_type => content_type,
        :content_size => file.size,
        :resource     => file
      }
    end

    def build_normal_attachments model, attachments
      (attachments || []).each do |attach|
        model.attachments.build({:content => attach[:resource], :description => attach[:description], :account_id => model.account_id, :content_file_name => attach[:filename]})
      end
    end

    def create_attachment(item, i, options)
      Helpdesk::Attachment.create_attachment_from_url(Account.current, item, options, i, 1)
    end

    def create_inline_attachment(item, i, options)
      Helpdesk::Attachment.create_for_3rd_party(Account.current, item, options, i, 1, false, false)
    end

    def attachment_url attachment, default_url, type = :original
      attachment_present?(attachment) ? (Account.current.one_hop_enabled? ? attachment.inline_url : attachment.content(type)) : default_url
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
