module S3Helper
	def stub_s3_writes
		AWS::S3::S3Object.any_instance.stubs(:write).returns(true)
		AWS::S3::S3Object.any_instance.stubs(:delete).returns(true)
	end

  def unstub_s3_writes
    AWS::S3::S3Object.any_instance.unstub(:write)
    AWS::S3::S3Object.any_instance.unstub(:delete)
  end
end