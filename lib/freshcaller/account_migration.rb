module Freshcaller
  module AccountMigration
    def create_freshcaller_account
      response_data = {}
      account = ::Account.current
      return unless account_admin
      protocol = Rails.env.development? ? 'http://' : 'https://'
      signup_params = {
        signup: {
          user_name: account_admin.name,
          user_email: account_admin.email,
          account_name: account.name,
          time_zone:  ActiveSupport::TimeZone[account.time_zone].utc_offset,
          account_domain: "#{FreshcallerConfig['domain_prefix']}#{account.domain}",
          skip_provider: true,
          plan_name: plan_name,
          subscription_period: subscription_period,
          api: {
            activation_required: false,
            account_name: account.name,
            account_id: account.id,
            freshdesk_calls_url: "#{protocol}#{account.full_domain}/api/channel/freshcaller_calls",
            app: 'Freshdesk',
            client_ip: client_ip,
            domain_url: "#{protocol}#{account.full_domain}",
            access_token: account_admin.single_access_token
          }
        }
      }
      Rails.logger.info "Signup params :: #{signup_params.inspect}"
      response_data = freshcaller_request(signup_params, "#{FreshcallerConfig['signup_domain']}/accounts", :post)
      response_data.symbolize_keys!
      Rails.logger.info "Signup Response for Account - #{account.id} :: #{response_data}"
      response_data
    end

    def fetch_freshfone_credits
      freshfone_credit = {}
      account = ::Account.current
      credit = account.freshfone_credit
      recharge_quantity = credit.recharge_quantity == 25 ? 50 : credit.recharge_quantity
      freshfone_credit = {
        available_credit: credit.available_credit,
        auto_recharge: credit.auto_recharge,
        recharge_quantity: recharge_quantity
      }
      credit.update_attributes(available_credit: 0)
      File.open("#{account_migration_location}/freshfone_credit.json", 'w') do |f|
        f.write(freshfone_credit.to_json)
      end
      Rails.logger.info "Credit migration for account :: #{account.id} completed"
    end

    def fetch_agent_limits
      agent_limits = {}
      account = ::Account.current
      limit = { agent_limit: account.subscription.agent_limit }
      File.open("#{account_migration_location}/agent_limit.json", 'w') do |f|
        f.write(limit.to_json)
      end
      Rails.logger.info "Agent limit for account :: #{account.id} completed"
    end

    def fetch_business_calendars
      business_calendars = []
      duplicates = {}
      account = ::Account.current
      account.business_calendar.find_in_batches(batch_size: 10) do |calendar_batch|
        calendar_batch.each do |business_calendar|
          business_calendar_name = business_calendar.name.downcase
          if duplicates[business_calendar_name].nil?
            duplicates[business_calendar_name] = 0
          else
            duplicates[business_calendar_name] += 1
          end

          calendar_name = duplicates[business_calendar_name] > 1 ? "#{business_calendar.name}_#{duplicates[business_calendar_name] - 1}" : business_calendar.name
          duplicates[calendar_name] = 1 if duplicates[business_calendar_name] > 1
          business_calendar_hash = { name: calendar_name,
                                     business_time_data: business_calendar.business_time_data,
                                     holiday_data: business_calendar.holiday_data,
                                     description: business_calendar.description,
                                     time_zone: business_calendar.time_zone,
                                     is_default: business_calendar.is_default }
          business_calendars << business_calendar_hash
        end
      end
      File.open("#{account_migration_location}/business_calendars.json", 'w') do |f|
        f.write(business_calendars.to_json)
      end
      Rails.logger.info "Business calendar migration for account :: #{account.id} completed"
    end

    def plan_name
      return 'Advance' if ::Account.current.subscription.addons.where(name: "Call Center Advanced").present?
      'Standard'
    end

    def subscription_period
      return 'annual' if ::Account.current.subscription.renewal_period == 12
      'monthly'
    end

    def client_ip
      return account_admin.last_login_ip if account_admin.last_login_ip.present?
      account_admin.current_login_ip
    end
  end
end
