module Ecommerce::Ebay::Util

  include Ecommerce::Ebay::Constants
  include Social::Util

  def session_store(data_to_be_stored)
    data_to_be_stored.each do |key,val|
      session[key] = val
    end
  end

  def delete_session
    EBAY_SESSION_DATA.each do |key|
      session.delete(key)
    end
  end

  def encode_params(data)
    CGI::escape(data.to_query)
  end

  def sent_folder_messages(ebay_account_id, start_time, end_time) 
    messages = []
    EBAY_MAX_PAGE.each do |page_number|
      sent_message = Ecommerce::Ebay::Api.new({:ebay_account_id => ebay_account_id}).make_ebay_api_call(:fetch_messages_in_sent_folder, :start_time => start_time, 
        :end_time => end_time,:detail_level => "headers",:page_number => page_number)

      if sent_message && sent_message[:messages].present?
        (messages << sent_message[:messages][:message]).flatten!
      else
        break
      end

    end
    messages
  end

  def ebay_user(user_id)
    "#{EBAY_PREFIX}-#{user_id}"
  end

  def tag_ecommerce_user(user, tag_name)
    tag = Account.current.tags.find_by_name(tag_name) || Account.current.tags.new(:name => tag_name)
    begin
      user.tags << tag
    rescue ActiveRecord::RecordInvalid => e
    end
  end

  def create_ebay_attachments(account, item, message_id, media_array)
    return unless media_array

    attachments = []
    media_url_hash = {}
    media_array = [media_array] if media_array.is_a?(Hash)
    begin
      media_array.each do |media|
        media_url = media['MediaURL']
        file_name = media['MediaName']
        options = {
          file_content: open(media_url),
          filename: file_name,
          content_type: get_content_type(file_name),
          content_size: 1000
        }
        image_attachment = Helpdesk::Attachment.create_for_3rd_party(account, item, options, 1, 1, false)
        if image_attachment.present? && image_attachment.content.present?
          media_url_hash[media_url] = image_attachment.inline_url
          attachments << image_attachment
        end
      end
    rescue StandardError => e
      Rails.logger.info "Error attaching media from ebay, message : #{message_id} : Exception: #{e.class} : Exception Message: #{e.message} : Backtrace: #{e.backtrace[0..10]}"
    end
    item.inline_attachments = attachments.compact
    media_url_hash
  end
end