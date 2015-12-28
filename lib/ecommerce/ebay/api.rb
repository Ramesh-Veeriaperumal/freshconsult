class Ecommerce::Ebay::Api

  include Ecommerce::Ebay::ErrorHandler
  include Ecommerce::Ebay::Constants
  include Redis::IntegrationsRedis
  include Redis::RedisKeys

  def initialize(args)
    @ebay_account_id = args[:ebay_account_id]
    @site_id = args[:site_id]
  end

  def make_ebay_api_call(method_call, params=nil)
    ebay_sandbox {
      response = send(method_call,params)
      Rails.logger.debug "Api response for call #{method_call}, params - #{params} \n #{response} \n"
      check_expiry if response[:hard_expiration_warning].present? 
      incr_counter if response[:ack] == EBAY_SUCCESS_MSG
      log_error(response) if response[:ack] == EBAY_ERROR_MSG
      response
    }
  end 

  def fetch_session_id(args)
    Ebayr.call(:GetSessionID, @ebay_account_id , :site_id => @site_id ,:input => [{ :RuName => Ebayr.ru_name }])
  end

  def fetch_auth_token(args)
    Ebayr.call(:FetchToken, @ebay_account_id, :site_id => @site_id, :input => [{ :SessionID => args[:session_id] }])
  end

  def subscribe_to_notifications(args)
    Ebayr.call(:SetNotificationPreferences, @ebay_account_id, :site_id => @site_id, :auth_token => args[:auth_token],
               :input => 
               [ 
                  {
                    :UserDeliveryPreferenceArray => construct_notification(args[:enable_type])
                  }
                ] 
              )
  end

  def construct_notification(enable_type)
    notification_array =[]
    EBAY_EVENT_TYPES.each do |key,val|
      notify_hash = { :NotificationEnable => {:EventEnable => EBAY_ENABLE_TYPE[enable_type] , :EventType => val } }
      notification_array.push(notify_hash)
    end
    notification_array
  end

  def fetch_messages_in_sent_folder(args)
    Ebayr.call(:GetMyMessages,@ebay_account_id, :input =>[
      { :FolderID => EBAY_SENT_FOLDER_ID }, 
      { :StartTime => args[:start_time].utc - 2.minutes },
      { :EndTime => args[:end_time].utc },
      { :DetailLevel => EBAY_DETAIL_LEVEL[args[:detail_level]] },
      { :Pagination => {:EntriesPerPage => EBAY_MAX_ENTRY, :PageNumber => args[:page_number] }} 
    ])
  end

  def item_details(args)
    Ebayr.call(:GetItem,@ebay_account_id,:input =>[ {:DetailLevel => EBAY_DETAIL_LEVEL[args[:detail_level]]}, {:ItemID => "#{args[:item_id]}"}]) 
  end

  def fetch_message_by_id(args)
    Ebayr.call(:GetMyMessages,@ebay_account_id,
      :input => [
          { :FolderID => EBAY_SENT_FOLDER_ID }, 
          { :ExternalMessageIDs => {:ExternalMessageID => args[:external_message_id] } },
          { :DetailLevel => EBAY_DETAIL_LEVEL[args[:detail_level]] } 
      ])
  end

  def reply_to_buyer(args)
    ebay_attachment_urls = []
    ticket = args[:ticket]
    note   = args[:note]
    ebay_questionable = Account.current.ebay_questions.where(
      "ebay_questions.questionable_id in (?) and ebay_questions.questionable_type = ? and ebay_questions.message_id IS NOT NULL",
      ticket.notes.where(:incoming => true).pluck(:id),"Helpdesk::Note").last if ticket.notes.present?
    ebay_questionable = ticket.ebay_question if ebay_questionable.blank?
    msg_id = ebay_questionable.message_id
    usr_external_id = ticket.requester.external_id.gsub("#{EBAY_PREFIX}-","")

    note.attachments.each do |attach|
      attach_resp = upload_ebay_picture(attach.content_file_name, attach.authenticated_s3_get_url)
      ebay_attachment_urls.push({:name => attach.content_file_name, :url => attach_resp[:site_hosted_picture_details][:full_url]}) if attach_resp[:ack] != EBAY_ERROR_MSG
    end

    Ebayr.call(:AddMemberMessageRTQ,@ebay_account_id, :MemberMessage => [{:Body => CGI.escapeHTML(note.body)},
      construct_media(ebay_attachment_urls), 
      {:ParentMessageID => msg_id, :RecipientID => usr_external_id}]) if msg_id.present? and usr_external_id.present?
  end

  def construct_media(attachment_urls)
    media = []
    attachment_urls[0..4].each do |attach|
      media.push({
        :MessageMedia =>  {
          :MediaName => attach[:name], 
          :MediaURL  => attach[:url]
        }
      })
    end
    media
  end

  def upload_ebay_picture(name, url)
    Ebayr.call(:UploadSiteHostedPictures, @ebay_account_id, :input =>[{:PictureName => name}, {:ExternalPictureURL => CGI.escapeHTML(url)}])
  end

  def fetch_user(args)
    Ebayr.call(:GetUser, @ebay_account_id, :auth_token => args[:auth_token] ,:site_id => @site_id, :input => [{ :OutputSelector => "EIASToken" }])
  end

  def log_error(error_details)
    if EBAY_RATE_LIMIT_ERROR.include?(error_details[:errors][:error_code])
      raise Error::ApiLimitError.new(error_details[:errors])
    elsif error_details[:errors][:error_code] == EBAY_INVALID_ARGS_ERROR
      raise Error::ArgumentError.new(error_details[:errors]) 
    elsif error_details[:errors][:error_code] == EBAY_AUTHENTICATION_FAILURE
      deactivate_account
      raise Error::AuthenticationError.new(error_details[:errors])  
    else
      raise Error::ApiError.new(error_details[:errors])  
    end
  end

  def check_expiry
    if @ebay_account_id
      ebay_acc = fetch_ebay_account_id
      EcommerceNotifier.token_expiry(ebay_acc.name, ebay_acc.account, ebay_acc.configs[:hard_expiration_time]) unless ebay_acc.reauth_required
      ebay_acc.reauth_required = true
      ebay_acc.save
    end
  end

  def deactivate_account
    if @ebay_account_id
      ebay_acc = fetch_ebay_account_id
      ebay_acc.status = Ecommerce::EbayAccount::ACCOUNT_STATUS[:inactive]
      ebay_acc.save
    end
  end

  def fetch_ebay_account_id
    @ebay_account ||= Account.current.ebay_accounts.find_by_id(@ebay_account_id)
  end

  def incr_counter
    ebay_account_counter = get_integ_redis_key(ebay_account_key)
    application_counter = get_integ_redis_key(application_key)

    expire_time = (Time.now.utc + 1.week).to_i

    set_integ_redis_key(application_key , 0, expire_time) if application_counter.blank?
    application_counter = incr_val(application_key)
    
    set_integ_redis_key(ebay_account_key , 0, expire_time) if ebay_account_counter.blank?
    ebay_account_counter = incr_val(ebay_account_key)

    EcommerceNotifier.notify_threshold_limit(application_counter) if (application_counter == EBAY_API_LOW_WARNING_LIMIT || application_counter == EBAY_API_HIGH_WARNING_LIMIT)
  end

  def application_key
    EBAY_APP_THRESHOLD_COUNT % {  :date => Time.now.utc.strftime("%Y-%m-%d"), :app_id => Ebayr.app_id }
  end

  def ebay_account_key
    EBAY_ACCOUNT_THRESHOLD_COUNT % { :date => Time.now.utc.strftime("%Y-%m-%d"), :account_id => Account.current.id, :ebay_account_id =>  @ebay_account_id}
  end

  module Error
    class ApiLimitError < StandardError 
    end
    class ArgumentError < StandardError 
    end
    class AuthenticationError < StandardError 
    end
    class ApiError < StandardError 
    end
  end
end