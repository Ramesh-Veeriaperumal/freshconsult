require 'clearbit'
class ContactEnrichment
  include Sidekiq::Worker
  include Redis::RedisKeys
  include Redis::OthersRedis
  sidekiq_options :queue => :data_enrichment, :retry => 0, :failures => :exhausted

  def perform(args = {})
    email_update = args['email_update']
    account = Account.current
    return if account.opt_out_analytics_enabled?
    begin
      email_id = account.contact_info[:email]
      result = Clearbit::Enrichment.find(email: email_id, stream: true)
      account.account_configuration.contact_info = generate_clearbit_contact_info(result, email_update)
      account.account_configuration.contact_info_will_change!
      account_company_info = account.account_configuration.company_info.dup
      account.account_configuration.company_info = account_company_info.merge(generate_clearbit_company_info(result))
      account.account_configuration.company_info_will_change!
      account.account_configuration.save
    rescue Nestful::ClientError, Nestful::ResourceInvalid,Nestful::ResourceNotFound  => e
      error_log = "CLEARBIT ERROR. Account: #{account.full_domain}, Id: #{account.id}, error: #{e}"
      code = e.response.code
      case code
        when "402"
          if Rails.env.production? && !redis_key_exists?(CLEARBIT_NOTIFICATION)
            FreshdeskErrorsMailer.error_email(nil, nil, e, {
                :subject => error_log, :recipients => ["ramesh@freshdesk.com", "arvinth@freshdesk.com"],
            })
            set_others_redis_key(CLEARBIT_NOTIFICATION, Time.now)
          end

        else
          Rails.logger.error error_log
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e)
      Rails.logger.error("Error while contact enrichment: \n#{e}")
    end
  end

  def generate_clearbit_contact_info(result, email_update)
    person_contact_info = {:full_name => result.try(:[], "person").try(:[], 'name').try(:[], 'fullName'),
                           :first_name => result.try(:[], "person").try(:[], 'name').try(:[], 'givenName'),
                           :last_name => result.try(:[], "person").try(:[], 'name').try(:[], 'familyName'),
                           :email_provider => result.try(:[], "person").try(:[], 'emailProvider').to_s,
                           :country => result.try(:[], "person").try(:[], 'geo').try(:[], 'country'),
                           :time_zone => result.try(:[], "person").try(:[], 'timeZone'),
                           :employment_name => result.try(:[], "person").try(:[], 'employment').try(:[], 'name'),
                           :job_title => result.try(:[], "person").try(:[], 'employment').try(:[], 'title'),
                           :twitter => result.try(:[], "person").try(:[], 'twitter').try(:[], 'handle'),
                           :facebook => result.try(:[], "person").try(:[], 'facebook').try(:[], 'handle'),
                           :linkedin => result.try(:[], "person").try(:[], 'linkedin').try(:[], 'handle')
    }
    person_contact_info.reject! { |k, v| v.nil? || v.empty? }
    merge_type = (email_update || Account.current.email_signup?)  ? :merge : :reverse_merge
    account_contact_info = Account.current.contact_info
    account_contact_info.reject! { |k,v| v.nil? || v.empty? }
    account_contact_info.safe_send(merge_type, person_contact_info)
  end

  def generate_clearbit_company_info(result)
    company_contact_info = {:name => result.try(:[], "company").try(:[], 'name'),
                            :site_title => result.try(:[], "company").try(:[], 'site').try(:[], 'title'),
                            :site_h1 => result.try(:[], "company").try(:[], 'site').try(:[], 'h1'),
                            :site_description => result.try(:[], "company").try(:[], 'site').try(:[], 'metaDescription'),
                            :phone_numbers => result.try(:[], "company").try(:[], 'site').try(:[], 'phoneNumbers'),
                            :industry => result.try(:[], "company").try(:[], 'category').try(:[], 'industry'),
                            :tags => result.try(:[], "company").try(:[], 'tags'),
                            :location => result.try(:[], "company").try(:[], 'geo'),
                            :twitter => result.try(:[], "company").try(:[], 'twitter').try(:[], 'handle'),
                            :facebook => result.try(:[], "company").try(:[], 'facebook').try(:[], 'handle'),
                            :linkedin => result.try(:[], "company").try(:[], 'linkedin').try(:[], 'handle'),
                            :crunchbase => result.try(:[], "company").try(:[], 'crunchbase').try(:[], 'handle'),
                            :logo => result.try(:[], "company").try(:[], 'logo'),
                            :metrics => result.try(:[], "company").try(:[], 'metrics')
    }
    company_contact_info.reject! { |k, v| v.nil? || v.empty? }
    company_contact_info
  end

end
