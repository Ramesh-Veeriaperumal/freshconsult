module ChannelIntegrations::Commands::Services
  class Twitter
    include ChannelIntegrations::Utils::ActionParser
    include ChannelIntegrations::Constants
    include ChannelIntegrations::CommonActions::Note
    include ChannelIntegrations::CommonActions::Ticket
    include Social::Twitter::Util
    include Redis::OthersRedis
    include Redis::RedisKeys
    
    def receive_create_ticket(payload)
      return error_message('Invalid request') unless check_ticket_params?(payload)

      context = payload[:context]
      data = payload[:data]

      set_current_user(data[:requester_id])
      check_twitter_handle?(context[:twitter_handle_id])

      Rails.logger.debug("Twitter::CreateTicket, account_id: #{current_account.id}, tweet_id: #{context[:tweet_id]}")
      payload[:data][:tweet_attributes] = get_tweet_attributes(context) # Pre-processing the payload to make entries in social_tweets.

      reply = create_ticket(payload)
      update_last_dm_id(context) if context[:tweet_type].to_sym == :dm

      reply
    rescue StandardError => e
      Rails.logger.error "Something wrong in Twitter::CreateTicket account_id: #{current_account.id}, context: #{context.inspect} #{e.message}"

      return conflict_error(context) if e.message.include? Social::Constants::TWEET_ALREADY_EXISTS
      error_message("Error in creating ticket, account_id: #{current_account.id}, context: #{context.inspect}")
    end

    def receive_create_note(payload)
      return error_message('Invalid request') unless check_ticket_params?(payload)

      context = payload[:context]
      data = payload[:data]
      ticket_id = payload[:data][:ticket_id]
      set_current_user(data[:user_id])
      check_twitter_handle?(context[:twitter_handle_id])

      Rails.logger.debug("Twitter::CreateNote, account_id: #{current_account.id}, tweet_id: #{context[:tweet_id]}")
      payload[:data][:tweet_attributes] = get_tweet_attributes(context) # Pre-processing the payload to make entries in social_tweets.

      reply = create_note(payload)
      update_last_dm_id(context) if context[:tweet_type].to_sym == :dm

      reply
    rescue StandardError => e
      Rails.logger.error "Something wrong in Twitter::CreateNote account_id: #{current_account.id}, context: #{context.inspect} #{e.message}"

      return archived_ticket_error(ticket_id) if e.message.include? Social::Constants::TICKET_ARCHIVED
      return conflict_error(context) if e.message.include? Social::Constants::TWEET_ALREADY_EXISTS
      error_message("Error in Creating note, account_id: #{current_account.id}, context: #{context.inspect}")
    end

    def receive_update_twitter_message(payload)
      context = payload[:context]
      data = payload[:data]

      return error_message('Invalid request') unless check_note_params?(payload)

      if data[:status_code] >= 400
        if (data[:status_code] == 403) && (data[:code] == ::Twitter::Error::Codes::CANNOT_WRITE)
          set_others_redis_key_if_not_present(TWITTER_APP_BLOCKED, true)
        end
        note_id = context[:note_id]
        schema_less_notes = current_account.schema_less_notes.find_by_note_id(note_id)
        return error_message('SchemaLessNote not found') if schema_less_notes.blank?

        update_errors_in_schema_less_notes(schema_less_notes, data, note_id)
      else
        return error_message('Tweet Id cannot be empty') unless data[:tweet_id].present?
        social_tweet = current_account.tweets.where(tweetable_id: context[:note_id], tweetable_type: 'Helpdesk::Note').first
        return error_message('Social::Tweet not found') if social_tweet.blank?

        update_tweet_in_social_tweets(social_tweet, data)
      end

      default_success_format
    rescue StandardError => e
      Rails.logger.error "Something wrong in update_twitter_message account_id: #{current_account.id}, context: #{context.inspect} #{e.message}"
      error_message("Error in update_twitter_message, account_id: #{current_account.id}, context: #{context.inspect}")
    end

    def receive_update_twitter_handle_error(payload)
      context = payload[:context]
      return error_message('Invalid request') if context[:twitter_handle_id].blank?

      if payload[:data][:status_code] == 401
        twitter_handle = current_account.twitter_handles.find_by_twitter_user_id(context[:twitter_handle_id])
        return error_message('Twitter Handle not found') if twitter_handle.blank?

        twitter_handle.state = Social::TwitterHandle::TWITTER_STATE_KEYS_BY_TOKEN[:reauth_required]
        twitter_handle.save!
      end

      default_success_format
    rescue StandardError => e
      Rails.logger.error "Twitter::update_twitter_handle_error account_id: #{current_account.id}, context: #{context.inspect} #{e.message}"
    end

    def receive_unblock_app(_payload)
      remove_others_redis_key(TWITTER_APP_BLOCKED)
      default_success_format
    rescue StandardError => e
      Rails.logger.error "Exception while unblocking twitter app, message: \
      #{e.message}, exception: #{e.backtrace}"
    end

    private

      def error_message(message)
        error = default_error_format
        error[:data] = { message: message }
        error
      end

      def archived_ticket_error(ticket_id)
        error = default_error_format
        error[:status_code] = Social::Constants::TWITTER_ERROR_CODES[:archived_ticket_error]
        error[:data] = { message: Social::Constants::TICKET_ARCHIVED,
                         ticket_id: ticket_id }
        error
      end

      def conflict_error(context)
        existing_tweet = current_account.tweets.find_by_tweet_id(context[:tweet_id])
        error = default_error_format
        error[:status_code] = 409
        error[:data] = { message: "Conflict: Tweet ID: #{context[:tweet_id]} already converted.",
                         id: existing_tweet.is_ticket? ? existing_tweet.tweetable.display_id : existing_tweet.tweetable_id }
        error
      end

      def check_ticket_params?(payload)
        context = payload[:context]
        context[:tweet_id].present? && base_validation?(context)
      end

      def check_note_params?(payload)
        context = payload[:context]

        context[:note_id].present? && base_validation?(context)
      end

      def base_validation?(context)
        context[:tweet_type].present? && context[:twitter_handle_id].present? && context[:stream_id].present?
      end

      # Catching the error and not throwing it as last_dm_id is a dummy column going forward.
      def update_last_dm_id(context)
        twt_handle = current_account.twitter_handles.find_by_twitter_user_id(context[:twitter_handle_id])
        twt_handle.update_attribute(:last_dm_id, context[:tweet_id])
      rescue StandardError => e
        Rails.logger.error "Twitter::update_last_dm_id failed, account_id: #{current_account.id}, context: #{context.inspect} #{e.message}"
        false
      end

      def update_errors_in_schema_less_notes(schema_less_notes, data, note_id)
        schema_less_notes.note_properties[:errors] = {} if schema_less_notes.note_properties[:errors].nil?
        twitter_errors = { twitter: { error_code: data[:status_code], error_message: data[:message], code: data[:code] } }
        schema_less_notes.note_properties[:errors].merge!(twitter_errors)

        schema_less_notes.save!
        notify_iris(note_id)
      end

      def update_tweet_in_social_tweets(social_tweet, data)
        social_tweet.tweet_id = data[:tweet_id]
        social_tweet.save!
      end

      def get_tweet_attributes(context)
        twitter_handle = check_twitter_handle?(context[:twitter_handle_id])
        {
          tweet_id: context[:tweet_id],
          tweet_type: context[:tweet_type].to_sym,
          twitter_handle_id: twitter_handle.id,
          stream_id: context[:stream_id]
        }
      end

      def twitter_handle_not_present_error
        error = default_error_format
        error[:data] = { message: 'The specified twitter handle is not present' }
        error
      end

      def set_current_user(requester_id)
        user = requester_id ? User.find(requester_id) : nil
        raise 'User not found' if user.blank?

        user.make_current
      end

      def check_twitter_handle?(handle_id)
        twitter_handle = current_account.twitter_handles.find_by_twitter_user_id(handle_id)
        raise 'Twitter Handle Not found' if twitter_handle.blank?

        twitter_handle
      end
  end
end
