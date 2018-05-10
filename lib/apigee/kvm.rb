class Apigee::KVM
  include Helpdesk::S3::Util

  AUTH_HEADER = {"apiKey"=> ApigeeConfig::API_KEY, "Content-Type" => "application/json"}
  REFRESH_TIMES = 3

  attr_accessor :valid_plan

  def initialize(params)
    raise "Plan not given" if params["plan"].blank?
    @valid_plan = check_plan(params["plan"])
  end

  def create(params)
    return unless @valid_plan
    
    if !Account.current.apigee_enabled?
      Account.current.launch(:apigee)
      update_in_s3("create", params["domain"])
      RestClient.get(ApigeeConfig::UPDATE_KVM_URI, headers(params))
    else
      Rails.logger.info "Apigee is already enabled for this account #{Account.current}. Change action to :update and try again"
    end
  end

  def update(params)
    return unless @valid_plan
    RestClient.get(ApigeeConfig::UPDATE_KVM_URI, headers(params))
  end

  def delete(params)
    if Account.current.apigee_enabled?
      Account.current.rollback(:apigee)
      update_in_s3("delete", params["domain"])
      RestClient.get(ApigeeConfig::UPDATE_KVM_URI, headers(params))
    else
      Rails.logger.info "Apigee is already disabled for this account #{Account.current}"
    end
  end

  def update_in_s3(action, domain)
    if action.present? && domain.present? && AwsWrapper::S3Object.find(ApigeeConfig::S3_FILE_NAME, ApigeeConfig::S3_BUCKET_NAME).exists?
      content = AwsWrapper::S3Object.read(ApigeeConfig::S3_FILE_NAME, ApigeeConfig::S3_BUCKET_NAME)
      if action == "create"
        unless content.include? domain
          content = content.present? ? content + "\n#{domain}" : domain
        else
          Rails.logger.info "Domain #{domain} is already present in s3 file"
        end
      elsif action == "delete"
        if content.include? domain
          final_domains_list = content.split("\n") - [domain]
          content = final_domains_list.join("\n")
        else
          Rails.logger.info "Domain #{domain} is not present in s3 file"
        end
      end
      AwsWrapper::S3Object.store(ApigeeConfig::S3_FILE_NAME, content, ApigeeConfig::S3_BUCKET_NAME)
      Rails.logger.info "#{action}d #{domain} info in s3 file"
    else
      Rails.logger.info "S3 bucket/file not found (or) action #{action} is not given or domain: #{domain} is not given"
    end
  end

  def clear_kvm_cache(domain)
    Rails.logger.info "Domain name #{domain}"
    return false if domain.nil?
    request_uri = ApigeeConfig::CLEAR_CACHE_URI
    clear_kvm_cache_headers = {"clear_cache"=> true, "domain"=> domain}.merge(AUTH_HEADER)
    REFRESH_TIMES.times do
      RestClient.get(request_uri, clear_kvm_cache_headers)
    end
  end

  def headers(params)    
    headers = params.present? ? params.merge(AUTH_HEADER) : AUTH_HEADER
  end

  def check_plan(plan)
    if ApigeeConfig::ALLOWED_PLANS.exclude?(plan)
      Rails.logger.info "#{plan} is not a valid plan"
      return false
    end
    return true
  end

end