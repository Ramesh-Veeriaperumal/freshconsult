class Signup < ActivePresenter::Base
  include Helpdesk::Roles

  presents :account, :user
  
  before_validation :build_primary_email, :build_portal, :build_roles, :build_admin,
    :build_subscription, :build_account_configuration, :set_time_zone
                    
  after_save :make_user_current, :populate_seed_data

  def locale=(language)
    @locale = (language.blank? ? I18n.default_locale : language).to_s
  end

  def time_zone=(utc_offset)
    utc_offset = utc_offset.blank? ? "Eastern Time (US & Canada)" : utc_offset.to_f
    @time_zone = (ActiveSupport::TimeZone[utc_offset]).name 
  end
    
  def metrics=(metrics_obj)
    account.conversion_metric_attributes = metrics_obj if metrics_obj
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
     default_roles_list.each do |role|
      account.roles.build(:name => role[0],
        :privilege_list => role[1],
        :description => role[2],
        :default_role => true)
      end
    end

    def build_admin
      user.roles = [account.roles.first]
      user.active = true  
      user.account = account
      user.helpdesk_agent = true
      user.build_agent()
      user.agent.account = account
    end
    
    def build_subscription
      account.plan = 
        SubscriptionPlan.find_by_name(SubscriptionPlan::SUBSCRIPTION_PLANS[:estate])
    end
    
    def build_account_configuration
      account.build_account_configuration(admin_contact_info)
    end
    
    def set_time_zone
      account.time_zone = @time_zone 
    end

    def default_preferences
      HashWithIndifferentAccess.new(
        {
          :bg_color => "#efefef",
          :header_color => "#252525",
          :tab_color => "#006063"
        }
      )
    end

    def admin_contact_info
      {
        :contact_info => { 
          :first_name => user.first_name,
          :last_name => user.last_name,
          :email => user.email,
          :phone => user.phone 
        },
      
        :billing_emails => { :invoice_emails => [ user.email ] }
      }
    end

    def make_user_current
      User.current = user
    end

    def populate_seed_data
      PopulateAccountSeed.populate_for(account)
    end
  
    def support_email
      "support@#{account.full_domain}"
    end

end