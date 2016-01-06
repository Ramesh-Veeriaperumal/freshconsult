require 'net/http'
require 'uri'
require 'spam/spam_result'

module Spam
  class SpamCheck
    
    include Redis::RedisKeys
    include Redis::OthersRedis  

    # Type of content to be passed for akismet
    COMMENT_TYPE = 'comment'

    #Default User Agent 
    USER_AGENT = 'Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2) Gecko/20100115 Firefox/3.6'

    def check_spam_content(content, options)
      content = CGI.unescapeHTML(content)
      result  = SpamResult::NO_SPAM
      urls    = parse_urls(content)
      result  = check_urls(urls) unless is_spam?(result)
      result  = is_spam_content(
                  content,  
                  options[:user_id], 
                  options[:remote_ip], 
                  options[:user_agent], 
                  options[:referrer]
                ) unless is_spam?(result)
      notify_spam(result, options)
      return result
    end

    def is_spam?(result)
      ((result == SpamResult::ERROR) || (result == SpamResult::NO_SPAM)) ? false : true
    end
    
    private
    
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

    def check_urls(urls)
      result = SpamResult::NO_SPAM
      urls.each do |url|
        result = check_spam_url url
        return result unless ((result == SpamResult::ERROR) || (result == SpamResult::NO_SPAM))
      end
      return result
    end

    def check_spam_url(uri_str, limit = 5)    
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
          msg = "Error in check_spam_url method: response - #{response}"
          notify_error(nil, nil, msg)
          return SpamResult::ERROR
        end
      rescue Exception => e
        msg = "Exception occurred while extracting urls"
        Rails.logger.error "#{msg} : #{e.message} - #{e.backtrace}"
        notify_error(nil, e, msg)
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
        msg = "Exception occurred while checking spam content"
        Rails.logger.error "#{msg}: #{e.message} - #{e.backtrace}"
        notify_error(request_params, e, msg)
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
      Object.const_get(:FreshdeskErrorsMailer).error_email(
        nil, 
        params, 
        nil, 
        {:subject => "Spam detected in ticket notifications"}
      ) if is_spam?(result)
    end
    
    def notify_error(params, e, msg)
      Object.const_get(:FreshdeskErrorsMailer).error_email(
        nil,
        params,
        e,
        {:subject => "#{msg}", :recipients => ["mail-team@freshdesk.com"]}
      )
    end
  end
end