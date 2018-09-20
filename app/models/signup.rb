class Signup < ActivePresenter::Base
  include Helpdesk::Roles
  include Redis::RedisKeys
  include Redis::OthersRedis

  presents :account, :user
  
  attr_accessor :contact_first_name, :contact_last_name, :org_id, :join_token
  before_validation :build_primary_email, :build_portal, :build_roles, :build_admin,
    :build_subscription, :build_account_configuration, :set_time_zone, :build_password_policy
  
  before_validation :create_global_shard

  after_save :make_user_current, :set_i18n_locale, :populate_seed_data
  after_save :create_freshid_org_and_account, if: :freshid_signup_allowed?

  MAX_ACCOUNTS_COUNT = 10
  #Using this as the version of Rack::Utils we are using doesn't have support for 429
  SIGNUP_RESPONSE_STATUS_CODES = {:too_many_requests => 429, :precondition_failed => 412}

  def locale=(language)
    @locale = (language.blank? ? I18n.default_locale : language).to_s
  end

  def time_zone=(utc_offset)
    utc_offset = utc_offset.blank? ? "Eastern Time (US & Canada)" : utc_offset.to_f
    t_z = ActiveSupport::TimeZone[utc_offset]
    @time_zone = t_z ? t_z.name : "Eastern Time (US & Canada)"
  end
    
  def metrics=(metrics_obj)
    account.conversion_metric_attributes = metrics_obj if metrics_obj
  end

  def all_errors
    error_messages = account.errors.messages
    base_errors = error_messages.delete(:base) || []
    non_base_errors = error_messages.collect{|key, values| error_messages = values.collect{|value| "#{key.to_s} #{value}" }} || []
    (base_errors + non_base_errors).flatten
  end

  def create_freshid_org_and_account
    account.create_freshid_org_and_account(org_id, join_token, user)
  end

  private
    def build_primary_email
      account.build_primary_email_config(
        :to_email => support_email,
        :reply_email => support_email,
        :name => account.name,
        :primary_role => true
      )
      account.primary_email_config.active = true
    end

    def build_portal
      account.build_main_portal(
        :name => account.name,
        :preferences => default_preferences,
        :language => @locale,
        :main_portal => true
      )
    end

    def build_roles
     DEFAULT_ROLES_LIST.each do |role|
      account.roles.build(:name => role[0],
        :default_role => true,
        :privilege_list => role[1],
        :description => role[2])
      end
    end

    def build_admin
      user.roles = [account.roles.first]
      user.active = true  
      user.account = account
      user.helpdesk_agent = true
      user.build_agent()
      user.agent.account = account
      user.build_primary_email({:email => user.email, :primary_role => true, :verified => false}) #user_email key sets after creation of account
      user.primary_email.account = account
      user.language = account.main_portal.language
    end
    
    def build_subscription      
      SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:estate_jan_17])
    end
    
    def build_account_configuration
      account.build_account_configuration(admin_contact_info)
    end
    
    def set_time_zone
      account.time_zone = @time_zone 
    end

    def build_password_policy
    account.build_default_password_policy(PasswordPolicy::USER_TYPE[:agent]) unless account.freshid_enabled?
    account.build_default_password_policy(PasswordPolicy::USER_TYPE[:contact])
   end

    def default_preferences
      HashWithIndifferentAccess.new(
        {
          :bg_color => "#efefef",
          :header_color => "#252525",
          :tab_color => "#006063",
          :personalized_articles => true
        }
      )
    end

    def admin_contact_info
      {
        :contact_info => { 
          :first_name => contact_first_name || user.first_name,
          :last_name => contact_last_name || user.last_name,
          :email => user.email,
          :phone => user.phone 
        },
        :company_info => {
          :name => account.name
        },
        :billing_emails => { :invoice_emails => [ user.email ] }
      }
    end

    def make_user_current
      User.current = user
    end

    def set_i18n_locale
      I18n.locale = account.language.to_sym
    end

    def populate_seed_data
      PopulateAccountSeed.populate_for(account)
    end
  
    def support_email
      "support@#{account.full_domain}"
    end

    def freshid_signup_allowed?
      redis_key_exists? FRESHID_NEW_ACCOUNT_SIGNUP_ENABLED
    end

    # * * * POD Operation Methods Begin * * *
    def create_global_shard 
      if Fdadmin::APICalls.non_global_pods? && account.valid?
        shard_record = construct_shard_parameters 
        begin
        global_pod_response = Fdadmin::APICalls.connect_main_pod(construct_shard_parameters)
        rescue Exception => e
          message = 'Unable to create your domain, Please contact support or try again later'
        end
        if global_pod_response && global_pod_response["account_id"] 
          create_nonglobal_shard(global_pod_response["account_id"],shard_record[:shard])
        else
          account.errors[:Sorry] << (message or 'Domain is not available!') 
          return false   
        end
      end
    end

    def construct_shard_parameters
      return {
        :domain => account.full_domain,
        :target_method => :set_shard_mapping_for_pods,
        :shard => build_shard
        }
    end

    def build_shard
      {
        :shard_name => ShardMapping.latest_shard,
        :status => ShardMapping::STATUS_CODE[:ok], 
        :pod_info => PodConfig['CURRENT_POD'],
        :region => PodConfig['CURRENT_REGION']
      }
    end    

    def create_nonglobal_shard(shard_mapping_id,shard_record)
      shard_mapping = ShardMapping.new(shard_record.merge(:status => 404))
      shard_mapping.domains.build({:domain => account.full_domain}) 
      shard_mapping.id = shard_mapping_id
      shard_mapping.save!
    end
    # * * * POD Operation Methods Ends * * *
end