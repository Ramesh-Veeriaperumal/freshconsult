# frozen_string_literal: true

module RuboCop
  module Cop
    module Gem
      class AwsS3 < Cop
        # This cop checks for S3 v1 usage.
        #
        # @example
        #
        #   # bad
        #   AwsWrapper::S3Object.store(file_path, file, bucket_name, server_side_encryption: :aes256, expires: 30.days)
        #   # good
        #   AwsWrapper::S3.put(bucket_name, file_path, file, server_side_encryption: 'AES256', expires: (Time.now + 30.days))

        MSG = 'Use `AwsWrapper::S3` instead of V1 S3 `AwsWrapper::S3Object`. Ref: <a href="https://github.com/freshdesk/helpkit/blob/107d8709231df7bc8bf107569628715ebfa57e9d/script/rubocop/cop/readme.md#gemawss3">New syntax</a>'.freeze

        def_node_matcher :s3_object?, '(send $(const (const nil? :AwsWrapper) :S3Object) ...)'

        def on_send(node)
          s3_object?(node) do |second_arg|
            add_offense(second_arg)
          end
        end
      end
    end
  end
end

