module Facebook
  module Util

    include Facebook::Constants
    include Facebook::Exception::Notifier
    include EmailHelper
    include ActionView::Helpers

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
        return false if user_blocked?(core_obj.koala_post.requester_fb_id)
        if via_comment
          # Skipping optimal check(last argument: false) if its comment and convert_post_to_ticket. Refer: FD-16831.
          core_obj.fan_page.default_ticket_rule.convert_fb_feed_to_ticket?(core_obj.koala_post.by_visitor?, core_obj.koala_post.by_company?, core_obj.koala_comment.by_visitor?, '' , true)
        else
          core_obj.fan_page.default_ticket_rule.convert_fb_feed_to_ticket?(core_obj.koala_post.by_visitor?)
        end
    end  
    
    # convert_company_commment_too. When true creates a ticket for company comment. Happens when a user replies to a company comment. 
    def convert_comment_to_ticket?(core_obj, convert_company_comment_to_ticket = false)
      core_obj.fetch_parent_data
      core_obj.fan_page.default_ticket_rule.convert_fb_feed_to_ticket?(false, core_obj.koala_post.by_company?, (core_obj.koala_comment.by_visitor? || convert_company_comment_to_ticket), core_obj.koala_comment.description) && !user_blocked?(core_obj.koala_comment.requester_fb_id)
    end

    def convert_cover_photo_comment_to_ticket?(core_obj)
      core_obj.fan_page.default_ticket_rule.convert_fb_feed_to_ticket?(false, false, core_obj.koala_comment.by_visitor?, core_obj.koala_comment.description, false, true) && !user_blocked?(core_obj.koala_comment.requester_fb_id)
    end
    
    #Parse the feed content from facebook post
    def html_content_from_feed(feed, item, original_post = nil)
      html_content =  CGI.escapeHTML(feed[:message]) if feed[:message]
      if "video".eql?(feed[:type])
        desc = feed[:description] || ""
        thumbnail, inline_attachment = create_inline_attachment_and_get_url(feed[:picture], item, 0)
        html_content = FEED_VIDEO % { :target_url => feed[:link], :thumbnail => thumbnail, 
          :att_url => feed[:link], :name => feed[:name], :html_content => html_content, :desc => desc } if thumbnail.present?

      elsif "photo".eql?(feed[:type])
        photo_url, inline_attachment = create_inline_attachment_and_get_url(feed[:picture], item, 0)
        html_content = FEED_PHOTO % { :html_content => html_content, :link => feed[:link],
         :photo_url => photo_url, :height => "" } if photo_url.present?
      elsif "link".eql?(feed[:type])
        link_story   = "<a href=\"#{feed[:link]}\">#{feed[:name]}</a>" if feed[:name]
        html_content = FEED_LINK % {:html_content => html_content, :link_story => link_story}
      end
      inline_attachment = nil unless attachment_present?(inline_attachment)
      item.inline_attachments = [inline_attachment].compact
      html_content
    end

    #Parse the feed content from facebook post
    def html_content_from_original_post(feed, item)
      html_content =  CGI.escapeHTML(feed[:message]) if feed[:message]
      page_name = feed[:from][:name]
      # posting_time = DateTime.parse(feed[:created_time]).strftime("%B %C at %I:%M %p")
      html_content = html_content.first(PARENT_POST_LENGTH) + "..." if html_content.length > PARENT_POST_LENGTH
      if "video".eql?(feed[:type])
        desc = feed[:description] || ""
        thumbnail, inline_attachment = create_inline_attachment_and_get_url(feed[:picture], item, 0)
        html_content = FEED_VIDEO_WITH_ORIGINAL_POST % { :target_url => feed[:link], :thumbnail => thumbnail, 
          :att_url => feed[:link], :name => feed[:name], :html_content => html_content, :desc => desc, :page_name => page_name } if thumbnail.present?

      elsif "photo".eql?(feed[:type])
        photo_url, inline_attachment = create_inline_attachment_and_get_url(feed[:picture], item, 0)
        html_content = FEED_PHOTO_WITH_ORIGINAL_POST % { :html_content => html_content, :link => feed[:link],
         :photo_url => photo_url, :height => "", :page_name => page_name} if photo_url.present?
      elsif "link".eql?(feed[:type])
        link_story   = "<a href=\"#{feed[:link]}\">#{feed[:name]}</a>" if feed[:name]
        html_content = FEED_LINK_WITH_ORIGINAL_POST % { :html_content => html_content, :link_story => link_story, :page_name => page_name }
      else
        html_content = FEED_WITH_ORIGINAL_POST % {:html_content => html_content, :page_name => page_name
    }
      end
      inline_attachment = nil unless attachment_present?(inline_attachment)
      item.inline_attachments = [inline_attachment].compact
      html_content
    end
    
    #Parse the feed content from facebook comment
    def html_content_from_comment(feed, item, original_post = nil)
      html_content =  CGI.escapeHTML(feed[:message]) if feed[:message] 
      unless feed[:attachment]
        return original_post.present? ? ( COMMENT_WITH_ORIGINAL_POST % {comment: html_content, original_post: original_post} ) : html_content 
      end
      
      begin
        attachment = feed[:attachment].symbolize_keys!     
        if "share".eql?(attachment[:type])
          desc = feed[:description] || ""
          link_story   = "<a href=\"#{attachment[:url]}\">#{attachment[:title]}</a>" if attachment[:title]
          html_content = COMMENT_SHARE % {:html_content => html_content, :link_story => link_story}
        elsif ["photo","sticker","video_inline", "animated_image_video"].include?(attachment[:type])
          height = attachment[:type] == "sticker" ? "200px" : ""
          photo_url, inline_attachment = create_inline_attachment_and_get_url(attachment[:media][:image][:src], item, 0)

          if photo_url.present?
            html_content = if original_post.present?
                COMMENT_PHOTO_WITH_ORIGINAL_POST % {:html_content => html_content, :link => attachment[:target][:url],
                 :photo_url => photo_url, :height => height, :original_post => original_post}
              else
                COMMENT_PHOTO % { :html_content => html_content, :link => attachment[:target][:url],
                 :photo_url => photo_url, :height => height }
            end
          end
        end
      rescue => e
        Rails.logger.debug("Error while parsing attachment in comment:: #{feed[:id]} :: #{feed[:attachment]}")
      end
      inline_attachment = nil unless attachment_present?(inline_attachment)
      item.inline_attachments = item.inline_attachments + [inline_attachment].compact
      html_content
    end
    
    #Parse the feed content from facebook message
    def html_content_from_message(message, item, original_post = nil)
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
                 :height => "300px" } if attached_url
              else
                url = (attachment[:video_data].present?) ? attachment[:video_data][:url] : attachment[:file_url]
                content_objects << get_options(url, attachment, false)
              end
            end
          end
          html_content = "#{html_content} </p></div>"
          content_objects = content_objects.reject { |obj| obj.nil? }
          html_content = build_normal_attachments(item, content_objects, html_content)
          html_content
        end
      elsif message[:shares] #### for stickers 
        if message[:shares][:data]
          html_content =  "<div class=\"facebook_post\"><p> #{html_content}</p><p>"
          message[:shares][:data].each_with_index do |share, i|
            if share[:link]
              url = share[:link]
              file = URI.parse(url).open # Moved here to avoid multiple calls
              stickers_url, inline_attachment = create_inline_attachment_and_get_url(url, item, i, file)
              inline_attachments.push(inline_attachment) if attachment_present?(inline_attachment)
              
              html_content = MESSAGE_SHARE % {:html_content => html_content, :url => stickers_url,
               :height => "200px"} if stickers_url

              content_url = get_content_url(file, url) if !attachment_present?(inline_attachment) && !stickers_url
              html_content = "#{html_content}<br>" if message[:message].present? && content_url # For new line creation
              html_content = LINK_SHARE % {:html_content => html_content, :title => I18n.t('ticket.share_facebook'), :url => content_url} if content_url
            elsif share[:name] || share[:description]
              html_content = share_content(html_content, share)
            end
          end
          html_content = "#{html_content} </p></div>"
        end
      end
      item.inline_attachments = inline_attachments.compact
      html_content
    end

    def create_inline_attachment_and_get_url url, item, i, file = nil
      options = get_options(url, {}, true, file)
      if options.is_a? Hash
        inline_attachment = create_inline_attachment(item, i, options)
        attached_url = attachment_url inline_attachment, url
        return [attached_url, inline_attachment]
      end
      return [nil,nil]
    end

    def get_content_url file, url
      return (!file.nil? && file.content_type.split('/').last == "html") ? url : nil
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

    def get_options(url, attachment_params = {}, inline = false, file = nil)
      file = open(url) if file.nil?
      if !inline || INLINE_FILE_FORMATS.include?(file.content_type.split('/').last)
        file_name = attachment_params[:name] || url.split(URL_DELIMITER).first[url.rindex(URL_PATH_DELIMITER)+1, url.length]
        content_type = file_name.split(FILENAME_DELIMITER).last
        return {
          :file_content => file,
          :filename     => file_name,
          :content_type => content_type,
          :content_size => file.size,
          :resource     => file
        }
      # else
      #   @addl_text = "#{@addl_text}<p> #{url} </p>" if @fan_page.launched?(:shop)
      end
    rescue RuntimeError, Exception => e
      Rails.logger.debug "#{e.message} A: #{@fan_page.account_id} Page ID: #{@fan_page.page_id} Page Obj ID:#{@fan_page.id} U:#{url}"
      return nil
    end

    def build_normal_attachments model, attachments, html_content
      (attachments || []).each do |attach|
        model.attachments.build({:content => attach[:resource], :description => attach[:description], :account_id => model.account_id, :content_file_name => attach[:filename]}, {:attachment_limit => HelpdeskAttachable::FACEBOOK_ATTACHMENTS_SIZE})  
      end
    rescue HelpdeskExceptions::AttachmentLimitException => e
      Rails.logger.error e
      message = attachment_exceeded_message(HelpdeskAttachable::FACEBOOK_ATTACHMENTS_SIZE)
      add_notification_text model, message, html_content
      error = {:error => "Facebook HelpdeskExceptions::AttachmentLimitException", :exception => "Exception #{e} Item #{model.inspect}, attachments #{attachments.inspect}"}
      notify_fb_mailer(nil, error, error[:error])
    ensure
      return html_content
    end

    def add_notification_text item, message, html_content
      notification_text_html = Helpdesk::HTMLSanitizer.clean(content_tag(:div, message, :class => "attach-error"))
      html_content << notification_text_html if item.is_a?(Helpdesk::Ticket) || item.is_a?(Helpdesk::Note)
      html_content
    end

    def create_attachment(item, i, options)
      Helpdesk::Attachment.create_attachment_from_url(Account.current, item, options, i, 1)
    end

    def create_inline_attachment(item, i, options)
      Helpdesk::Attachment.create_for_3rd_party(Account.current, item, options, i, 1, false)
    end

    def attachment_url attachment, default_url, type = :original
      attachment_present?(attachment) ? attachment.inline_url : default_url
    end

    def filter_messages_from_data_set(data_set)
      message_id_arr   = data_set[:data].collect { |message| message[:id] }
      existing_msg_arr = Account.current.facebook_posts.where(post_id: message_id_arr).pluck(:post_id).to_set
      data_set[:data].reject { |message| ((existing_msg_arr.include? message[:id]) || @fan_page.created_at > Time.zone.parse(message[:created_time])) }
    end

    def social_revamp_enabled?
      @social_revamp_enabled ||= Account.current.features?(:social_revamp)
    end

    def latest_message(thread_key = nil)
      fb_msg = nil
      Sharding.run_on_slave do 
        fb_msg = @account.facebook_posts.latest_thread(thread_key, 1, @fan_page.id).first if thread_key
      end
      fb_msg
    end

    def share_content(html_content, share)
      shared_name = share[:name]
      shared_description = share[:description]
      html_content = "#{html_content}<br> #{I18n.t('ticket.share_facebook')}<br>"
      html_content = format(TEXT_SHARE, html_content: html_content, name: I18n.t('export_data.agents.fields.name'), value: shared_name) if shared_name.present?
      html_content = format(TEXT_SHARE, html_content: html_content, name: I18n.t('export_data.fields.description'), value: shared_description) if shared_description.present?
      html_content
    end
  end
end
