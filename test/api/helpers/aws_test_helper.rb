module AwsTestHelper
  def stub_all
    # https://aws.amazon.com/blogs/developer/client-response-stubs/
    # http://docs.aws.amazon.com/sdk-for-ruby/v2/developer-guide/stubbing.html
    # http://docs.aws.amazon.com/sdkforruby/api/Aws/ClientStubs.html
    AWS.stub!
    Aws.config[:stub_responses] = true
  end

  def stub_s3_writes
    AWS::S3::S3Object.any_instance.stubs(:write).returns(true)
    AWS::S3::S3Object.any_instance.stubs(:delete).returns(true)
  end

  def stub_sqs_client
    Aws::SQS::Client.new(stub_responses: true)
  end

  def unstub_s3_writes
    AWS::S3::S3Object.any_instance.unstub(:write)
    AWS::S3::S3Object.any_instance.unstub(:delete)
  end
end
