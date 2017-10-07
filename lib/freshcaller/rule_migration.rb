module Freshcaller
  module RuleMigration
    def fetch_freshfone_objects(account_id)
      @numbers = []
      Sharding.select_shard_of(account_id) do
        Sharding.run_on_slave do
          account = ::Account.find(account_id)
          if account.present? && account.all_freshfone_numbers.present?
            account.make_current
            account.freshfone_numbers.each do |number|
              @messages = []
              voice_type = number.female_voice? ? 0 : 1
              fetch_message_type(number, voice_type)
              fetch_messages_from_ivr(number, voice_type, account)
              fetch_business_calendars_hash(account)
              business_calendar_name = @s_duplicates[number.business_calendar_id]
              @numbers << { number: number.number, queue_wait_time: number.queue_wait_time, max_queue_length: number.max_queue_length,
                            voicemail_active: number.voicemail_active, hunt_type: number.hunt_type, rr_timeout: number.rr_timeout,
                            ringing_time: number.ringing_time, queue_position_preference: number.queue_position_preference,
                            queue_position_message: number.queue_position_message, message_type: number.ivr.message_type,
                            business_calendar_name: business_calendar_name, group_name: group_name(account, number), messages: @messages }
            end
          end
        end
      end
      File.open("#{account_migration_location}/rules.json", 'w') do |f|
        f.write(@numbers.to_json)
      end
      Rails.logger.info "Rule Migration for account :: #{account_id} completed"
      ::Account.reset_current_account
    end

    private

      def fetch_message_type(number, voice_type)
        fetch_message(number.on_hold_message, voice_type, current_account) if number.on_hold_message.present?
        fetch_message(number.non_availability_message, voice_type, current_account) if number.non_availability_message.present?
        fetch_message(number.voicemail_message, voice_type, current_account) if number.voicemail_message.present?
        fetch_message(number.non_business_hours_message, voice_type, current_account) if number.non_business_hours_message.present?
        fetch_message(number.wait_message, voice_type, current_account) if number.wait_message.present?
        fetch_message(number.hold_message, voice_type, current_account) if number.hold_message.present?
      end

      def fetch_messages_from_ivr(number, voice_type, account)
        ivr = number.ivr
        if ivr.message_type
          if ivr.simple_message?
            fetch_message(ivr.welcome_message, voice_type, account)
          else
            ivr.menus.each do |menu|
              fetch_message(ivr.find_menu(menu.menu_id), voice_type, account, true)
            end
          end
        end
      end

      def fetch_message(message, voice_type, account, ivr = false)
        name = ivr ? message.name : message.type.to_s
        message_hash = { name: name, message_voice_type: voice_type }
        if message.message_type == Freshfone::MessageMethods::MESSAGE_TYPES[:transcript]
          message_hash[:message_text] = message.message
          message_hash[:message_type] = 3
        else
          message_type = message.message_type + 1
          create_recording_file(account, message)
          open("#{account_migration_location}/#{@file_name}", 'wb') { |file| file << open(@url).read }
          message_hash.merge!(data: "#{account_migration_location}/#{@file_name}", data_file_name: @file_name, message_type: message_type)
        end
        fetch_ivr_options(account, message, message_hash) if ivr
        @messages << message_hash
      end

      def create_recording_file(account, message)
        if message.message_type == Freshfone::MessageMethods::MESSAGE_TYPES[:recording] && message.recording_url.present?
          @url = "#{message.recording_url}.mp3"
          @file_name = File.basename(@url)
        else
          attachment = account.attachments.where(id: message.attachment_id).first
          if attachment.present?
            @url = attachment.expiring_url
            @file_name = attachment.content_file_name
          else
            @url = Freshfone::Number::DEFAULT_WAIT_MUSIC
            @file_name = File.basename(@url)
          end
        end
      end

      def fetch_ivr_options(account, message, message_hash)
        options = []
        message.options.each do |option|
          case option.performer.to_s
          when 'User'
            @user = account.users.where(id: option.performer_id).first
            @performer_name = if @user.present?
                                @user.email
                              else
                                @performer_name = 'all_agents'
                              end
          when 'Group'
            @group = account.groups.where(id: option.performer_id).first
            @performer_name = if @group.present?
                                @group.name
                              else
                                @performer_name = 'all_agents'
                              end
          else
            @performer_name = option.performer.to_s
          end
          parent_menu_id = message.parent.present? ? message.parent.menu_id : nil
          options << { performer: option.performer.to_s, performer_name: @performer_name, performer_id: option.performer_id, key: option.respond_to_key, number: option.performer_number, menu_id: message.menu_id, parent_menu_id: parent_menu_id, menu_name: message.menu_name }
        end
        message_hash.merge!(ivr_options: options)
      end

      def fetch_business_calendars_hash(account)
        duplicates = {}
        @s_duplicates = {}
        account.business_calendar.each do |business_calendar|
          business_calendar_name = business_calendar.name.downcase
          if duplicates[business_calendar_name].nil?
            duplicates[business_calendar_name] = 0
          else
            duplicates[business_calendar_name] += 1
          end
          calendar_name = duplicates[business_calendar_name] > 1 ? "#{business_calendar.name}_#{duplicates[business_calendar_name] - 1}" : business_calendar.name
          @s_duplicates[business_calendar.id] = calendar_name
          if duplicates[business_calendar_name] > 1
            duplicates[calendar_name] = 1
          end
        end
      end

      def group_name(account, number)
        return nil unless number.ivr.simple_message?
        group_id = number.ivr.group_id
        if group_id
          return nil if group_id.zero?
          group = account.groups.where(id: number.ivr.group_id).first
          group.name
        end
      end
  end
end
