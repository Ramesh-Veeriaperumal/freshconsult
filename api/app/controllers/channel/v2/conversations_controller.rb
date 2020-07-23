module Channel::V2
  class ConversationsController < ::ConversationsController

    include Conversations::Twitter
    skip_before_filter :can_send_user?

    CHANNEL_V2_CONVERSATIONS_CONSTANTS_CLASS = 'Channel::V2::ConversationConstants'.freeze

    def create
      conversation_delegator = invoke_delegator
      if conversation_delegator.valid?(:create)
        is_success = create_note
        render_response(is_success)
      else
        render_custom_errors(conversation_delegator, true)
      end
    end
    
    private

      def invoke_delegator
        delegator_class.new(@item, delegator_params)
      end

      def conversation_delegator_class
        'ConversationDelegator'.constantize
      end

      def social_delegator_class
        'Channel::V2::SocialDelegator'.constantize
      end

      def delegator_class
        social_source? ? social_delegator_class : conversation_delegator_class
      end

      def constants_class
        CHANNEL_V2_CONVERSATIONS_CONSTANTS_CLASS
      end

      def validation_class
        Channel::V2::ConversationValidation
      end

      def validate_params
        field = "#{constants_class}::#{action_name.upcase}_FIELDS".constantize | ['source_additional_info' => 'twitter']
        params[cname].permit(*field)
        params_hash = params[cname].merge({})
        if params_hash[:source_additional_info].present? && params_hash[:source_additional_info].is_a?(Hash)
          params_hash[:twitter] = params_hash[:source_additional_info][:twitter] if twitter_reply?
        end
        @conversation_validation = validation_class.new(params_hash, @item, string_request_params?)
        valid = @conversation_validation.valid?(action_name.to_sym)
        render_errors @conversation_validation.errors, @conversation_validation.error_options unless valid
        valid
      end

      def sanitize_params
        super
        if create_action? && twitter_reply?
          @tweet = params[cname][:source_additional_info][:twitter]
          if @tweet.present?
            handle = Account.current.twitter_handles.where(twitter_user_id: @tweet[:support_handle_id]).first
            @tweet[:twitter_handle_id] = handle.present? && handle.id ? handle.id : nil
          end
        end
        params[cname].delete(:source_additional_info)
      end

      def create_note
        @item.import_note = true if import_api?
        build_twitter_reply_attributes if @tweet.present?
        super
      end

      def build_twitter_reply_attributes
        reply_handle = current_account.twitter_handles.find_by_id(@tweet[:twitter_handle_id])
        stream_id = @tweet[:stream_id] || reply_handle.default_stream_id
        tweet_id = @tweet[:tweet_id] || random_tweet_id
        @item.build_tweet(tweet_id: tweet_id,
                          tweet_type: @tweet[:tweet_type],
                          twitter_handle_id: @tweet[:twitter_handle_id],
                          stream_id: stream_id)
      end

      def delegator_params
        params_hash = {
          notable: @ticket
        }
        params_hash[:twitter_handle_id] =  @tweet[:twitter_handle_id] if social_source?
        params_hash
      end

      def twitter_reply?
        params[cname][:source] == current_account.helpdesk_sources.note_source_keys_by_token['twitter']
      end

      def assign_private
        params[cname][:private]
      end

      def assign_source
        params[cname][:source] || super
      end

      def create_action?
        action_name == 'create'
      end

      def social_source?
        [current_account.helpdesk_sources.note_source_keys_by_token['twitter']].include?(params[cname][:source])
      end

      def check_agent_note
        # Channel api should allow updating notes made by customers too
      end
  end
end
