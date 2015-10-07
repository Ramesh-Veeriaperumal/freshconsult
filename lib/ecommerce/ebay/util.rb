module Ecommerce::Ebay::Util

  include Ecommerce::Ebay::Constants

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
    user.tags << tag
  end

end