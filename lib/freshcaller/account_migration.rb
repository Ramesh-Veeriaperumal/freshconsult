module Freshcaller
  module AccountMigration
    def create_freshcaller_account(account_id)
      response_data = {}
      Sharding.select_shard_of(account_id) do
        Sharding.run_on_slave do
          account = ::Account.find(account_id)
          if account.present? || account.freshfone_account.present?
            account.make_current
            roles = account.roles.where(name: 'Account Administrator').first
            users = account.users.where(privileges: roles.privileges).reorder('id asc')
            return if users.blank?
            user = users.first
            signup_params = {
              signup: {
                user_name: user.name,
                user_email: user.email,
                account_name: account.name,
                account_domain: account.domain,
                api: {
                  activation_required: true,
                  account_name: account.name,
                  account_id: account_id
                }
              }
            }
            Rails.logger.info "Signup params :: #{signup_params.inspect}"
            response_data = freshcaller_request(signup_params, "#{FreshcallerConfig['signup_domain']}/accounts", :post)
            response_data.symbolize_keys!
            Rails.logger.info "Signup Response for Account - #{account_id} :: #{response_data}"
          end
        end
      end
      ::Account.reset_current_account
      response_data
    end

    def fetch_freshfone_credits(account_id)
      freshfone_credit = {}
      Sharding.select_shard_of(account_id) do
        account = ::Account.find(account_id)
        return unless account.present? || account.freshfone_account.present?
        credit = account.freshfone_credit
        recharge_quantity = credit.recharge_quantity == 25 ? 50 : credit.recharge_quantity
        freshfone_credit = {
          available_credit: credit.available_credit,
          auto_recharge: credit.auto_recharge,
          recharge_quantity: recharge_quantity
        }
        credit.update_attributes(available_credit: 0)
      end
      File.open("#{account_migration_location}/freshfone_credit.json", 'w') do |f|
        f.write(freshfone_credit.to_json)
      end
      Rails.logger.info "Credit migration for account :: #{account_id} completed"
      ::Account.reset_current_account
    end

    def fetch_business_calendars(account_id)
      business_calendars = []
      duplicates = {}
      Sharding.select_shard_of(account_id) do
        Sharding.run_on_slave do
          account = ::Account.find(account_id)
          if account.present? && account.business_calendar.present?
            account.make_current
            account.business_calendar.each do |business_calendar|
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
        end
      end
      File.open("#{account_migration_location}/business_calendars.json", 'w') do |f|
        f.write(business_calendars.to_json)
      end
      Rails.logger.info "Business calendar migration for account :: #{account_id} completed"
      ::Account.reset_current_account
    end
  end
end
