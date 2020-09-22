# frozen_string_literal: true

module RuboCop
  module Cop
    module Gem
      class AwsGlobalVar < Cop
        # This cop checks for v1 global variable usage.
        #
        # @example
        #
        #   # bad
        #   $sns_client = AWS::SNS.new.client(...)
        #   # good
        #   $sns_client = Aws::SNS::Client.new(...)

        GVAR_MSG = 'Try to create/use V2 client global variable instead existing V1 global client variables. Ref: <a href="https://github.com/freshdesk/helpkit/blob/107d8709231df7bc8bf107569628715ebfa57e9d/script/rubocop/cop/readme.md#gemawsglobalvar">New syntax</a>'.freeze
        NOT_ALLOWED_VARIABLE = %w[$sqs_reports_service_export $sqs_forum_moderation $sqs_scheduled_ticket_export $sqs_twitter $dynamo $sqs_client $sqs_forum_moderation $sqs_euc $social_dynamo $sqs_spam_analysis $sqs_cti $sqs_email_failure_reference $sqs_twitter_global $sqs_twitter_eu $sqs_twitter_euc $sqs_reports_helpkit_export $sqs_facebook $sqs_facebook_messages $sqs_facebook_global].map(&:to_sym)

        def not_allowed_var?(global_var)
          NOT_ALLOWED_VARIABLE.include?(global_var)
        end

        def on_gvasgn(node)
          check(node)
        end

        def on_gvar(node)
          check(node)
        end

        def check(node)
          global_var, = *node

          add_offense(node, message: GVAR_MSG, location: :name) if not_allowed_var?(global_var)
        end
      end
    end
  end
end
