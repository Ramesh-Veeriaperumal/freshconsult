module FdSpamDetectionService
  class Service

    def initialize(user, mail = nil)
      @mail = mail
      @user = user
      @timeout = FdSpamDetectionService.config.timeout
    end

    def check_spam
      result = process_response({})
      return result unless FdSpamDetectionService.config.global_enable or @mail.nil? or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/get_email_score"
      res = HTTParty.post(url, :body => {:message => @mail, :username => @user, :timeout => @timeout})
      process_response(res)
    rescue Exception => e
      Rails.logger.info "Error in SDS check spam: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return result
    end

    def learn_spam
      return false unless FdSpamDetectionService.config.global_enable or @mail.nil? or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/learn_spam"
      res = HTTParty.post(url, :body => {:message => @mail, :username => @user, :timeout => @timeout})
      res["success"].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS learn spam: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    def learn_ham
      return false unless FdSpamDetectionService.config.global_enable or @mail.nil? or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/learn_ham"
      res = HTTParty.post(url, :body => {:message => @mail, :username => @user, :timeout => @timeout}) 
      res['success'].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS learn ham: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    def forget
      return false unless FdSpamDetectionService.config.global_enable or @mail.nil? or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/forget"
      res = HTTParty.post(url, :body => {:message => @mail, :username => @user, :timeout => @timeout}) 
      res['success'].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS forget: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    def add_tenant
      return false unless FdSpamDetectionService.config.global_enable or @user.nil?
      url = FdSpamDetectionService.config.service_url + "/admin/add_tenant"
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
      res = HTTParty.post(url, :body => {:username => @user, :new_username => new_user, :timeout => @timeout})
      res['success'].to_s.to_bool
    rescue Exception => e
      Rails.logger.info "Error in SDS domain change: #{e.message} - #{e.backtrace}"
      NewRelic::Agent.notice_error(e)
      return false
    end

    private

    def process_response(hash)
      @resp = Result.new(hash)
    end

  end
end