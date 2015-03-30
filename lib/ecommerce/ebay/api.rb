class Ecommerce::Ebay::Api

  include Ecommerce::Ebay::ErrorHandler
  include Ecommerce::Constants 

  def initialize(ebay_acc_id)
    @ecom_acc = Account.current.ecommerce_accounts.find(ebay_acc_id)
    @ecom_acc.configs.each do |key, val|
      eval("Ebayr.#{key} = val")
    end
    Ebayr.sandbox = false
  end

  def make_call(method_call, params=nil)
    ebay_sandbox {
      response = send(method_call,params)
      check_expiry(response)
      log_error(response) if response[:ack] == EBAY_ERROR_MSG
      response
    }
  end

  private

    def item_details(args)
      Ebayr.call(:GetItem, :DetailLevel => "ReturnAll", :ItemID => "#{args[:item_id]}", :ErrorLanguage => EBAY_ERROR_LANGUAGE) if args[:item_id].present?
    end

    def parent_message_id(args)
      start_date = (Time.zone.now - 1.day).strftime("%Y-%m-%d")
      Ebayr.call(:GetMemberMessages, :MailMessageType => "All", :MessageStatus => "Unanswered", :StartCreationTime => start_date, :ErrorLanguage => EBAY_ERROR_LANGUAGE)
    end

    def reply_to_buyer(args)
      ebay_attachment_urls = []
      ticket = args[:ticket]
      note   = args[:note]

      msg_id = ticket.ebay_item.message_id
      usr_external_id = ticket.requester.user_external_id

      note.attachments.each do |attach|
        attach_resp = upload_ebay_picture(attach.content_file_name, attach.authenticated_s3_get_url)
        ebay_attachment_urls.push({:name => attach.content_file_name, :url => attach_resp[:site_hosted_picture_details][:full_url]}) if attach_resp[:ack] != "Failure"
      end

      note.shared_attachments.each do |shared_attach|
        attach_resp = upload_ebay_picture(shared_attach.attachment.content_file_name, shared_attach.attachment.authenticated_s3_get_url)
        ebay_attachment_urls.push({:name => shared_attach.attachment.content_file_name, :url => attach_resp[:site_hosted_picture_details][:full_url]}) if attach_resp[:ack] != "Failure"
      end

      Ebayr.call(:AddMemberMessageRTQ, :MemberMessage => [{:Body => RailsFullSanitizer.sanitize(note.body)},
        construct_media(ebay_attachment_urls), 
        {:ParentMessageID => msg_id, :RecipientID => usr_external_id, :ErrorLanguage => EBAY_ERROR_LANGUAGE}]) if msg_id.present? and usr_external_id.present?
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
      Ebayr.call(:UploadSiteHostedPictures, :PictureName => name, :ExternalPictureURL => CGI.escapeHTML(url), :ErrorLanguage => EBAY_ERROR_LANGUAGE)
    end

    def check_account_status(params)
      Ebayr.call(:GetAccount, :ErrorLanguage => EBAY_ERROR_LANGUAGE)
    end

    def log_error(error_details)
      if EBAY_RATE_LIMIT_ERROR.include?(error_details[:errors][:error_code])
        raise Error::ApiLimitError.new(error_details[:errors])
      elsif error_details[:errors][:error_code] == EBAY_INVALID_ARGS_ERROR
        raise Error::ArgumentError.new(error_details[:errors]) 
      elsif error_details[:errors][:error_code] == EBAY_AUTHENTICATION_FAILURE
        raise Error::AuthenticationError.new(error_details[:errors])  
      else
        raise Error::ApiError.new(error_details[:errors])  
      end
    end

    def check_expiry(response)
      EcommerceNotifier.send_later(:deliver_token_expiry, @ecom_acc.name, Account.current, response[:hard_expiration_warning]) unless response[:hard_expiration_warning].blank?
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