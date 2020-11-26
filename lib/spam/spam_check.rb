require 'net/http'
require 'uri'
require 'spam/spam_result'
require 'json'

module Spam
  class SpamCheck
    
    include Redis::RedisKeys
    include Redis::OthersRedis  
    include EmailHelper

    # Type of content to be passed for akismet
    COMMENT_TYPE = 'comment'

    #Default User Agent 
    USER_AGENT = 'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2) Gecko/20100115 Firefox/3.6'

    def build_content(subject, message)
      "Subject : #{subject}  Message :  #{message}"
    end

    def check_spam_content(subject, message, options)
      content = CGI.unescapeHTML(build_content(subject, message))
      result  = SpamResult::NO_SPAM
      return result if account_whitelisted?
      urls    = parse_urls(content)
      result  = check_urls(urls) unless is_spam?(result)
      spam_index = content =~ /Content-Type\s?:\s?application\/xml|Content-Type\s?:\s?text\/html/i unless is_spam?(result)

      if spam_index && !is_spam?(result)
        result = SpamResult::SPAM_CONTENT
      end
      # result  = is_spam_content(
      #             content,  
      #             options[:user_id], 
      #             options[:remote_ip], 
      #             options[:user_agent], 
      #             options[:referrer]
      #           ) unless is_spam?(result)

      curr_account = Account.current
      unless is_spam?(result)
        spam_service_result = check_spam_service(subject, message)
        is_spam_positive = is_spam?(spam_service_result)
        Rails.logger.debug "Spam check service result is #{spam_service_result} for subject #{subject}"
        notify_spam_template(curr_account, subject, message) if is_spam_positive || spam_service_result == SpamResult::PROBABLE_SPAM
        disable_outgoing_email if is_spam_positive
      end

      options.merge!({:account_id => curr_account.id, :spam_result => result, :content => content})
      Rails.logger.debug "Spam check result is #{result} for params #{options}"
      notify_spam(result, options)
      check_and_disable_notification(result, options)
      return result
    end

    def is_spam?(result)
      ((result == SpamResult::ERROR) || (result == SpamResult::NO_SPAM) || (result == SpamResult::PROBABLE_SPAM)) ? false : true
    end

    def has_more_redirection_links?(subject, message, limit)
      content = CGI.unescapeHTML(build_content(subject, message))
      urls    = parse_urls(content)
      urls.each do |url|
        result = check_spam_url(url, limit, false)
        return true if (result == SpamResult::SPAM_TOO_MANY_REDIRECTION)
      end
      return false
    end
    
    private

    def construct_template(subject, message)
      "Subject: #{subject}\n\n#{message}\n"
    end

    def notify_spam_template(account, subject, message)
      account_id = account.id
      Rails.logger.info "Spam template found for account: #{account_id} subject: #{subject} message: #{message}"
      FreshdeskErrorsMailer.error_email(nil, { domain_name: account.full_domain }, nil, {
        subject: "Spam template found for account: Account : #{account_id}, Account state : #{Account.current.subscription.state}, Domain : #{Account.current.full_domain}", 
        recipients: [ 'mail-alerts@freshdesk.com', 'helpdesk@abusenoc.freshservice.com'],
        additional_info: { info: 'Spam template found in an account' }
      })
    end

    def build_http_post(uri, message)
      header = { 'Content-Type': 'application/x-www-form-urlencoded', 'Authorization': "Basic #{FdSpamDetectionService.config.api_key}" }
      http_post = Net::HTTP::Post.new(uri.path, header)
      curr_account = Account.current
      http_post.set_form_data({
        username: curr_account.id,
        account_creation_date: curr_account.created_at.strftime('%Y-%m-%d'),
        message: message
      })
      http_post
    end

    def check_spam_from_response(resp)
      resp_body = resp.body
      Rails.logger.info("spam check service result #{resp_body}")
      if resp.is_a? Net::HTTPSuccess
        result = JSON.parse(resp_body)
        if result['is_spam']
          # We can flag cetain rules, if any one of such flag exist in the spam result, we will return as SpamResult::SPAM_CONTENT
          # Else we will return SpamResult::PROBABLE_SPAM
          rules = result['rules']
          flagged_rules = $redis_others.lrange(SPAM_CHECK_TEMPLATE_FLAGGED_RULES, 0, -1)
          if rules.is_a?(Array) && flagged_rules.is_a?(Array)
            return SpamResult::SPAM_CONTENT unless (rules & flagged_rules).empty?
          end
          return SpamResult::PROBABLE_SPAM
        end
        return SpamResult::NO_SPAM
      end
      SpamResult::ERROR
    end

    def check_spam_service(subject, message)
      http = Net::HTTP::Persistent.new 'spam_check_service'
      begin
        spam_server_uri = URI "#{FdSpamDetectionService.config.service_url}/"

        # We are making two types of spam check request
        # 1st priority - We have to return SpamResult::SPAM_CONTENT if one of the request returns SpamResult::SPAM_CONTENT
        # 2nd priority - we have to return SpamResult::PROBABLE_SPAM if one of the request returns SpamResult::PROBABLE_SPAM
        # Else we return SpamResult::NO_SPAM

        template_check_uri = spam_server_uri + 'get_template_score'
        resp = http.request template_check_uri, build_http_post(template_check_uri, construct_template(subject, message))
        spam_result = check_spam_from_response resp
        return spam_result if spam_result == SpamResult::SPAM_CONTENT

        content_check_uri = spam_server_uri + 'get_content_score'
        plain_text_message = Helpdesk::HTMLSanitizer.html_to_plain_text message
        resp = http.request content_check_uri, build_http_post(content_check_uri, "#{subject} #{plain_text_message}")
        content_spam_result = check_spam_from_response resp
        return content_spam_result if content_spam_result == SpamResult::SPAM_CONTENT

        return spam_result if spam_result == SpamResult::PROBABLE_SPAM
        return content_spam_result
      rescue StandardError => exp
        Rails.logger.info("Error while spam check service request #{exp}")
      ensure
        http.shutdown
      end

      SpamResult::NO_SPAM
    end
    
    def is_spam_domain? domain
      domain.present? ? ismember?(EMAIL_TEMPLATE_SPAM_DOMAINS, domain) : false
    end

    def parse_urls(html_content)
      URI.extract(html_content,['http','https']).compact.uniq
      # Commented the below code as it ignores the url if the
      # attribute contains double quotes

      #doc = Nokogiri::HTML(html_content)
      #hrefs = doc.css("a").map do |link|
      #  if (href = link.attr("href")) && href.match(/^https?:/)
      #    href
      #  end
      #end.compact.uniq
    end

    def account_whitelisted?
      acc_id = Account.current.id
      !get_others_redis_key(notification_whitelisted_key(acc_id)).nil? || !$spam_watcher.get("#{acc_id}-").nil?
    end

    def notification_whitelisted_key(account)
      SPAM_NOTIFICATION_WHITELISTED_DOMAINS_EXPIRY % {:account_id => account}
    end

    def disable_outgoing_email
      curr_account = Account.current
      if curr_account.subscription.cmrr < FdSpamDetectionService.config.outgoing_block_mrr_threshold
        notify_outgoing_block(curr_account) if block_outgoing_email(curr_account.id)
      end
    end

    def notify_outgoing_block(account)
      subject = "Blocked outgoing email due to suspicious spam template :#{account.id}"
      additional_info = 'Emails template saved by the account has suspicious content.'
      additional_info << 'Outgoing emails blocked!!'
      notify_account_blocks(account, subject, additional_info)
      update_freshops_activity(account, 'Outgoing emails blocked due to spam email template', 'block_outgoing_email')
    end

    def check_and_disable_notification(result, params)
      if (7.days.ago.to_i < Account.current.created_at.to_i) && (result == SpamResult::SPAM_URL_DOMAIN || result == SpamResult::SPAM_CONTENT)
        Account.current.subscription.update_attributes(:state => "suspended")
        ShardMapping.find_by_account_id(Account.current.id).update_attributes(:status => 403)
        notify_account_block(result, params)
      end
    end

    def check_urls(urls)
      result = SpamResult::NO_SPAM
      urls.each do |url|
        limit = (is_paying_account? ? 5 : 2)
        result = check_spam_url(url, limit)
        return result unless ((result == SpamResult::ERROR) || (result == SpamResult::NO_SPAM))
      end
      return result
    end

    def is_paying_account?
      (Account.current.created_at < 5.months.ago) and (Account.current.subscription.paid_account?)
    end

    def check_spam_url(uri_str, limit = 5, notify_by_email = true)    
      begin
        uri = URI.parse(URI.encode(uri_str))

        # return error if the domain presents in our spam domain list.
        return SpamResult::SPAM_URL_DOMAIN if is_spam_domain?(uri.host)

        # return error if the http redirction more than threshold.
        return SpamResult::SPAM_TOO_MANY_REDIRECTION if limit == 0

        response = Net::HTTP.get_response(uri)
        case response
        when Net::HTTPSuccess     then return SpamResult::NO_SPAM
        when Net::HTTPRedirection then return check_spam_url(response['location'], limit - 1)
        else
          Rails.logger.debug "Invalid response - #{response} came while processing uri - #{uri.to_s}"
          notify_error({ :account_id => Account.current.id, :invalid_response => response, :failed_uri => uri.to_s }, nil) if notify_by_email
          return SpamResult::ERROR
        end
      rescue Exception => e
        msg = "Exception occurred in 'check_spam_url' method while processing URI : #{uri}"
        Rails.logger.error "#{msg} : #{e.message} - #{e.backtrace}"
        notify_error({ :account_id => Account.current.id, :failed_uri => uri.to_s }, e) if notify_by_email
        return SpamResult::ERROR
      end
    end
    
    def is_spam_content(content, user_id, remote_ip, user_agent, referrer = nil)
      begin        
        account = Account.current
        user = account.users.find_by_id(user_id)
        user = Account.account_managers.first unless user.present?
        referrer_url = referrer.present? ? referrer : account.full_url
        user_agent = user_agent.present? ? user_agent : USER_AGENT
        request_params = {
          :blog                 => account.full_url,
          :user_ip              => remote_ip,
          :referrer             => referrer_url,
          :user_agent           => user_agent,
          :comment_type         => COMMENT_TYPE,
          :comment_author       => user.name,
          :comment_author_email => user.email,
          :comment_content      => content,
          :is_test              => 1,
          :key                  => AkismetConfig::KEY
        }
        return Akismetor.spam?(request_params) ? SpamResult::SPAM_CONTENT : SpamResult::NO_SPAM
      rescue Exception => e
        msg = "Exception occurred in 'is_spam_content' method in spam_check class"
        Rails.logger.error "#{msg}: #{e.message} - #{e.backtrace}"
        notify_error(request_params, e)
        return SpamResult::ERROR
      end
    end

    # def is_spam_content(content, account_id, user_id, remote_ip, user_agent, referrer = nil)
    #   begin
    #     Sharding.select_shard_of(account_id) do
    #       Account.reset_current_account
    #       account = account.find_by_id(account_id)
    #       if account && account.make_current
    #         user = Account.users.find(user_id)
    #         referrer_url = referrer.present? ? referrer : account.full_url
    #         user_agent = user_agent.present? ? user_agent : USER_AGENT
    #         request_params = {
    #           :blog => account.full_url,
    #           :user_ip => remote_ip,
    #           :referrer => referrer_url,
    #           :user_agent => user_agent,
    #           :comment_type => COMMENT_TYPE,
    #           :comment_author => user.name,
    #           :comment_author_email => user.email,
    #           :comment_content => content,
    #           :is_test => 1,
    #           :key => AkismetConfig::KEY
    #         }
    #         return Akismetor.spam?(request_params) ? SpamResult::SPAM_CONTENT : SpamResult::NO_SPAM
    #       else
    #         return SpamResult::ERROR
    #       end
    #     end
    #   rescue
    #     Rails.logger.error "Exception occurred while searching based on UIDs: #{e.message} - #{e.backtrace}"
    #     return SpamResult::ERROR
    #   ensure
    #     Account.reset_current_account
    #   end
    # end

    def submit_spam(content, params)
      #To do
    end

    def submit_ham(content, params)
      #To do
    end
    
    def notify_spam(result, params)
      shard_info = ShardMapping.fetch_by_account_id(Account.current.id)
      Object.const_get(:FreshdeskErrorsMailer).error_email(
        nil, 
        params, 
        nil, 
        { subject: "Spam detected in ticket notifications : Account id : #{Account.current.id}, POD info : #{shard_info.pod_info}, Shard info : #{shard_info.shard_name}",
          recipients: ['dev-ops@freshdesk.com', 'helpdesk@abusenoc.freshservice.com'] }
      ) if is_spam?(result)
    end
    
    def notify_error(params, e)
      Object.const_get(:FreshdeskErrorsMailer).error_email(
        nil,
        params,
        e,
        {:subject => "Exception in ticket notifications", :recipients => ["email-team@freshdesk.com"]}
      )
    end

    def notify_account_block(params, e)
      Object.const_get(:FreshdeskErrorsMailer).error_email(
        nil,
        params,
        e,
        {:subject => "Account blocked:: #{Account.current.id} due to spam notification"}
      )
      subject = "Account blocked:: #{Account.current.id} due to spam notification"
      additional_info = "Spam content detected in email notifications sent"
      notify_account_blocks(Account.current, subject, additional_info)
      update_freshops_activity(Account.current, "Account blocked due to spam content detected in email notifications", "block_account")
    end
  end
end

