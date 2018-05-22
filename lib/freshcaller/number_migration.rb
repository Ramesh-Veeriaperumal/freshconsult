module Freshcaller
  module NumberMigration
    def fetch_freshfone_numbers
      numbers = []
      account = ::Account.current
      @account = { twilio_subaccount_id: account.freshfone_account.twilio_subaccount_id, twilio_subaccount_token: account.freshfone_account.twilio_subaccount_token, state: account.freshfone_account.state }
      @twilio_subaccount = ::Twilio::REST::Client.new(account.freshfone_account.twilio_subaccount_id, account.freshfone_account.twilio_subaccount_token).account
      account.all_freshfone_numbers.find_in_batches(batch_size: 10) do |number_batch|
        number_batch.each do |freshfone_number|
          @account[:numbers] ||= []
          caller_id_sid = freshfone_number.freshfone_caller_id.present? ? freshfone_number.freshfone_caller_id.number_sid : nil      
          begin
            twilio_number = @twilio_subaccount.incoming_phone_numbers.get(freshfone_number.number_sid)
            deleted = freshfone_number.deleted if twilio_number.phone_number
          rescue Exception => e
            freshfone_number.update_column(:deleted, true)
            deleted = true
          end
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
                          deleted: deleted,
                          caller_id_sid: caller_id_sid,
                          accessibility_groups: fetch_accessibity_group(freshfone_number) }
          @account[:numbers] << number_hash
        end
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
      account.freshfone_caller_id.find_in_batches(batch_size: 10) do |caller_id_batch|
        caller_id_batch.each do |freshfone_caller_id|
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
