module FdSpamDetectionService
  class Service

    def initialize(user, content = nil)
      @content = content
      @user = user
      @timeout = FdSpamDetectionService.config.timeout
      @header = { 'Authorization' => "Basic #{FdSpamDetectionService.config.api_key}" }
    end

    def check_spam
      result = process_response({})
      return result unless FdSpamDetectionService.config.global_enable or @content.nil? or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/get_email_score"
      Rails.logger.info "Sending check_spam score request for account_id : #{@user} "
      res = HTTParty.post(url, body: { message: @content, username: @user, timeout: @timeout }, headers: @header)
      process_response(res)
    rescue Exception => e
      Rails.logger.info "Error in SDS check spam: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return result
    end

    def learn_spam
      return false unless FdSpamDetectionService.config.global_enable or @content.nil? or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/learn_spam"
      Rails.logger.info "Sending learn_spam request for account_id : #{@user} "
      res = HTTParty.post(url, body: { message: @content, username: @user, timeout: @timeout }, headers: @header)
      res["success"].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS learn spam: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    def learn_ham
      return false unless FdSpamDetectionService.config.global_enable or @content.nil? or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/learn_ham"
      Rails.logger.info "Sending learn_ham request for account_id : #{@user} "
      res = HTTParty.post(url, body: { message: @content, username: @user, timeout: @timeout }, headers: @header)
      res['success'].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS learn ham: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    def forget
      return false unless FdSpamDetectionService.config.global_enable or @content.nil? or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/forget"
      Rails.logger.info "Sending spam forget request for account_id : #{@user} "
      res = HTTParty.post(url, body: { message: @content, username: @user, timeout: @timeout }, headers: @header)
      res['success'].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS forget: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    def add_tenant
      return false unless FdSpamDetectionService.config.global_enable or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/admin/add_tenant"
      Rails.logger.info "Sending spam add_tenant request for account_id : #{@user} "
      res = HTTParty.post(url, :body => {:username => @user, :timeout => @timeout})
      res['success'].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS add tenant: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    def delete_tenant
      return false unless FdSpamDetectionService.config.global_enable or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/admin/delete_tenant"
      Rails.logger.info "Sending spam delete_tenant request for account_id : #{@user} "
      res = HTTParty.post(url, :body => {:username => @user, :timeout => @timeout})
      res['success'].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS delete tenant: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    def change_threshold(new_threshold)
      return false unless FdSpamDetectionService.config.global_enable or @user.nil? or new_threshold.nil?
      url = FdSpamDetectionService.config.service_url + "/admin/change_threshold"
      Rails.logger.info "Sending spam change_threshold request for account_id : #{@user}"
      res = HTTParty.post(url, :body => {:username => @user, :value => new_threshold, :timeout => @timeout})
      res['success'].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS threshold change: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    def change_user(new_user)
      return false unless FdSpamDetectionService.config.global_enable or @user.nil? or new_user.nil?
      url = FdSpamDetectionService.config.service_url + "/admin/change_domain"
      Rails.logger.info "Sending spam change_user request for account_id : #{@user}"
      res = HTTParty.post(url, :body => {:username => @user, :new_username => new_user, :timeout => @timeout})
      res['success'].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS domain change: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    def check_spam_content(date)
      result = process_response({})
      return result unless FdSpamDetectionService.config.global_enable or @content.nil? or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/get_content_score"
      Rails.logger.info "Sending check_spam_content score request for account_id : #{@user}"
      res = HTTParty.post(url, body: { message: @content, username: @user, account_creation_date: date }, headers: @header) # by default level is set as 3 in spam service side. We can change label later
      Rails.logger.info "Response by spam service for check spam content #{res.body}"
      process_response(JSON.parse(res.body))
    rescue Exception => e
      Rails.logger.info "Error in SDS check spam content: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return result
    end

    private

    def process_response(hash)
      @resp = Result.new(hash)
    end
  end
end