require 'spec_helper'

describe Community::DynamoTables do

	before(:all) do
		$dynamo = AWS::DynamoDB::ClientV2.new
		Dynamo::CLIENT = $dynamo
		@time = Time.now.utc.to_i
		S3_CONFIG = YAML::load(ERB.new(File.read("#{Rails.root}/config/s3.yml")).result)["test"].symbolize_keys
	end

	after(:all) do
		$dynamo.list_tables[:table_names].each do |table_name|
			$dynamo.delete_table({:table_name => table_name }) if (table_name.include?("test") && table_name.include?(@time.to_s))
		end
	end

	it "should create the given month and year's table in Dynamo DB" do
		args = { :year => @time, :month => 12 }
		Community::DynamoTables.create(args)
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			dynamo_table_exists?(dynamo_table_name(klass,args)).should eql true
		end
	end

	it "should create (current_month+2) month's table in Dynamo DB if no parameter is passed" do
		args = { :year => (Time.now + 2.months).utc.strftime('%Y'), :month => (Time.now + 2.months).utc.strftime('%m') }
		Community::DynamoTables.create
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			dynamo_table_exists?(klass.afternext).should eql true
			$dynamo.delete_table({:table_name => dynamo_table_name(klass, args)})
		end
	end

	it "should drop the given month and year's table in Dynamo DB" do
		args = { :year => @time, :month => 8 } 
		Community::DynamoTables.create(args)
		Community::DynamoTables.drop(args)
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			dynamo_table_exists?(dynamo_table_name(klass,args)).should eql false
		end
	end

	it "should drop previous month's table in Dynamo DB if no parameter is passed" do
		time = (Time.now - 1.month).utc
		args = { :year => time.strftime('%Y'), :month => time.strftime('%m') }
		Community::DynamoTables.create(args)
		Community::DynamoTables.drop
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			dynamo_table_exists?(klass.previous).should eql false
		end
	end

	describe "it should delete attachments based on the given parameters" do

		it "should delete attachments in s3 with prefix 'spam_attachments' for the given month" do
			@attachment_arr = [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image33kb.jpg','image/jpeg')}]
			time = (Time.now - 5.months)
			folder_name = "spam_attachments/month_#{time.strftime('%Y_%m')}/dynamo_tables_spec/#{Time.now.utc.to_f * (10**7)}"
			store_attachments(folder_name)
			Community::DynamoTables.clear_attachments({:year => time.strftime('%Y'), :month => time.strftime('%m')})
			s3_bucket_objects = AWS::S3::Bucket.new(S3_CONFIG[:bucket]).objects.with_prefix("spam_attachments/month_#{time.strftime('%Y_%m')}")
			s3_bucket_objects.collect(&:key).blank?.should eql true
		end

		it "should delete previous month's attachments in s3 with prefix 'spam_attachments' if no parameter is passed" do
			@attachment_arr = [{:resource => Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')}]
			time = (Time.now - 1.months).utc.strftime('%Y_%m')
			folder_name = "spam_attachments/month_#{time}/dynamo_tables_spec/#{Time.now.utc.to_f * (10**7)}"
			store_attachments(folder_name)
			Community::DynamoTables.clear_attachments({})
			s3_bucket_objects = AWS::S3::Bucket.new(S3_CONFIG[:bucket]).objects.with_prefix("spam_attachments/month_#{time}")
			s3_bucket_objects.collect(&:key).blank?.should eql true
		end
	end
end