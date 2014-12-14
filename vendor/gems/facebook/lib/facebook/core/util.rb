module Facebook::Core::Util

  def truncate_subject(subject, count)
    #Rails.logger.debug "truncate subject #{subject}"
    (subject.length > count) ? "#{subject[0..(count - 1)]}..." : subject
  end

  #create the user profile if doen's exist
  def facebook_user(profile)
    if(profile.is_a?Hash)
      profile.symbolize_keys!
      profile_id = profile[:id]
      profile_name = profile[:name]
    else
      profile_id = profile
    end

    user = @account.all_users.find_by_fb_profile_id(profile_id)

    unless user
      unless(profile.is_a?Hash)
        profile =  @rest.get_object(profile_id)
        profile.symbolize_keys!
        profile_id = profile[:id]
        profile_name = profile[:name]
      end

      user = @account.contacts.new
      if user.signup!({
                        :user => {
                          :fb_profile_id => profile_id,
                          :name => profile_name.blank? ? profile_id : profile_name,
                          :active => true,
                          :helpdesk_agent => false
                        }
        })
      else
        Rails.logger.debug "unable to save the contact:: #{user.errors.inspect}"
      end
    end
    user
  end

  def new_data_set(data_set)
    message_id_arr = data_set[:data].collect{|x| x["id"]}
    existing_msg_arr = @account.facebook_posts.find(:all, :select =>:post_id, :conditions => {:post_id =>message_id_arr}).collect{|a|a.post_id}
    return data_set[:data].reject{|d| existing_msg_arr.include? d["id"]}
  end

  #push the feed into dynamo db to process it later when the app is reautharized
  def self.add_to_dynamo_db(hash_key, range_key, attribute)
    #id is page id
    begin
      dynamo_db_facebook = AwsWrapper::DynamoDb.new(SQS[:facebook_realtime_queue])
      query_options = {
        :item => {
          "page_id" => {
            :n => "#{hash_key}"
          },
          "timestamp" => {
            :n => "#{range_key}"
          },
          "feed" => {
            :s => "#{attribute}"
          }
        }
      }
      dynamo_db_facebook.write(query_options)
    rescue Exception => e
      Rails.logger.error "cannot write data to dynamo db"
      NewRelic::Agent.notice_error(e,{:description => "cannot write data to dynamo db"})
    end
  end

  def send_facebook_reply(parent_post_id = nil)
    fb_page = @parent.fb_post.facebook_page
    parent_post = parent_post_id.blank? ? @parent : @parent.notes.find(parent_post_id)
    if fb_page
      if @parent.is_fb_message?
        unless Facebook::Core::Message.new(fb_page).send_reply(@parent, @item)
          return flash[:notice] = t(:'facebook.error_on_reply_fb')
        end
      else
        unless Facebook::Core::Comment.new(fb_page, nil).send_reply(parent_post, @item)
          return flash[:notice] = t(:'facebook.error_on_reply_fb')
        end
      end
      flash[:notice] = t(:'flash.tickets.reply.success')
    end
  end

  #Parse the content from facebook
  def get_html_content_from_feed(feed)
    #Rails.logger.debug "get_html_content"
    html_content =  CGI.escapeHTML(feed[:message])

    if "video".eql?(feed[:type])
      desc = feed[:description] || ""
      html_content =  "<div class=\"facebook_post\"><a class=\"thumbnail\" href=\"#{feed[:link]}\" target=\"_blank\"><img src=\"#{feed[:picture]}\"></a>
        <div><p><a href=\"#{feed[:link]}\" target=\"_blank\"> #{feed[:name]}</a></p>
        <p><strong>#{html_content}</strong></p>
        <p>#{desc}</p></div></div>"
    elsif "photo".eql?(feed[:type])
      html_content =  "<div class=\"facebook_post\"><p> #{html_content}</p><p><a href=\"#{feed[:link]}\" target=\"_blank\"><img src=\"#{feed[:picture]}\"></a></p></div>"
    end

    return html_content
  end

  def get_html_content_from_message(message)
    #Rails.logger.debug "get_html_content"
    message = HashWithIndifferentAccess.new(message)
    html_content =  CGI.escapeHTML(message[:message])
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

    return html_content
  end

end
