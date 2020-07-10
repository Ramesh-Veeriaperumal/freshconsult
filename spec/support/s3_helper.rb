module S3Helper
  def stub_s3_writes
    Aws::S3::Client.any_instance.stubs(:get_object).returns(true)
    Aws::S3::Object.any_instance.stubs(:delete).returns(true)
  end

  def unstub_s3_writes
    Aws::S3::Client.any_instance.unstub(:get_object)
    Aws::S3::Object.any_instance.unstub(:delete)
  end
end