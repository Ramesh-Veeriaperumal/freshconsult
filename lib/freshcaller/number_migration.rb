module Freshcaller
  module NumberMigration
    def fetch_freshfone_numbers
      numbers = []
      account = ::Account.current
      @account = { twilio_subaccount_id: account.freshfone_account.twilio_subaccount_id, twilio_subaccount_token: account.freshfone_account.twilio_subaccount_token, state: account.freshfone_account.state }
      account.all_freshfone_numbers.each do |freshfone_number|
        @account[:numbers] ||= []
        caller_id_sid = freshfone_number.freshfone_caller_id.present? ? freshfone_number.freshfone_caller_id.number_sid : nil
        number_hash = { number: freshfone_number.number, display_number: freshfone_number.display_number,
                        name: freshfone_number.name,
                        region: freshfone_number.region,
                        country: freshfone_number.country,
                        number_sid: freshfone_number.number_sid,
                        number_type: freshfone_number.number_type,
                        rate: freshfone_number.rate,
                        next_renewal_at: freshfone_number.next_renewal_at,
                        state: freshfone_number.state,
                        voicemail_active: freshfone_number.voicemail_active,
                        recording_active: freshfone_number.record,
                        deleted: freshfone_number.deleted,
                        caller_id_sid: caller_id_sid,
                        accessibility_groups: fetch_accessibity_group(freshfone_number) }
        @account[:numbers] << number_hash
      end
      numbers << @account
      File.open("#{account_migration_location}/numbers.json", 'w') do |f|
        f.write(numbers.to_json)
      end
      Rails.logger.info "Number migration for account :: #{account.id} completed"
    end

    def fetch_caller_ids
      caller_ids = []
      account = ::Account.current
      if account && account.freshfone_caller_id
        account.freshfone_caller_id.each do |freshfone_caller_id|
          caller_id_obj = { number: freshfone_caller_id.number, number_sid: freshfone_caller_id.number_sid }
          caller_ids << caller_id_obj
        end
      end
      File.open("#{account_migration_location}/caller_ids.json", 'w') do |f|
        f.write(caller_ids.to_json)
      end
      Rails.logger.info "Caller id migration for account :: #{account.id} completed"
    end

    def fetch_accessibity_group(number)
      number.freshfone_number_groups.map { |number_group| 
        number_group.group.try(:name)
      }
    end
  end
end
