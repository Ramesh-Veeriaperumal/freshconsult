require 'spec_helper'

describe Community::DynamoTables do

	before(:all) do
		$dynamo = Aws::DynamoDB::Client.new
		Dynamo::CLIENT = $dynamo
		@read = 10
		@write = 10
		@inactive = 1
		@args_previous = { :year => (Time.now - 1.months).utc.strftime('%Y'), :month => (Time.now - 1.months).utc.strftime('%m') } 
		@args_before_previous = { :year => (Time.now - 2.months).utc.strftime('%Y'), :month => (Time.now - 2.months).utc.strftime('%m') } 
		@args_next = { :year => (Time.now + 1.months).utc.strftime('%Y'), :month => (Time.now + 1.months).utc.strftime('%m') } 
		@args_after_next = { :year => (Time.now + 2.months).utc.strftime('%Y'), :month => (Time.now + 2.months).utc.strftime('%m') } 
		S3_CONFIG = YAML::load(ERB.new(File.read("#{Rails.root}/config/s3.yml")).result)["test"].symbolize_keys
	end

	after(:all) do
		$dynamo.list_tables[:table_names].each do |table_name|
			$dynamo.delete_table({:table_name => table_name }) if table_name.include?("test")
		end
	end

	it "should create current_month+2 table and increase throughtput for current_month+1 table in Dynamo DB if no parameter is passed" do
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			table_name = dynamo_table_name(klass[0], @args_next)
			if not dynamo_table_exists?(table_name)
				Community::DynamoTables.construct(@args_next)
			end
		end

		Community::DynamoTables.create
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			table_name = dynamo_table_name(klass[0], @args_after_next)
			dynamo_table_exists?(table_name).should eql true

			table_name = dynamo_table_name(klass[0], @args_next)
			provisioned_throughput(table_name)[:read_capacity_units].should eql @read
			provisioned_throughput(table_name)[:write_capacity_units].should eql @write
		end
	end

	it "should construct the given timestamp's table in Dynamo DB" do
		Community::DynamoTables.construct(@args_after_next)
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			dynamo_table_exists?(dynamo_table_name(klass[0], @args_after_next)).should eql true
		end
	end

	it "should activate(increase throughtput) the given month and year's table in Dynamo DB" do
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|	
			if not dynamo_table_exists?(dynamo_table_name(klass[0], @args_next))
				Community::DynamoTables.construct(@args_next)
			end
		end

		Community::DynamoTables.activate(@args_next)
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			table_name = dynamo_table_name(klass[0], @args_next)
			provisioned_throughput(table_name)[:read_capacity_units].should eql @read
			provisioned_throughput(table_name)[:write_capacity_units].should eql @write
		end
	end


	it "should drop current_month-2 table and decrease throughtput for current_month-1 table in Dynamo DB if no parameter is passed" do
		Community::DynamoTables::MODERATION_CLASSES.each do |klass| 
			if not dynamo_table_exists?(dynamo_table_name(klass[0], @args_previous))
				Community::DynamoTables.construct(@args_previous)
			end
		end

		Community::DynamoTables.drop
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			table_name = dynamo_table_name(klass[0], @args_before_previous)
			dynamo_table_exists?(table_name).should eql false

			table_name = dynamo_table_name(klass[0], @args_previous)
			provisioned_throughput(table_name)[:read_capacity_units].should eql @inactive
			provisioned_throughput(table_name)[:write_capacity_units].should eql @inactive
		end
	end

	it "should delete the given month and year's table in Dynamo DB" do
		Community::DynamoTables.delete(@args_before_previous)
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			dynamo_table_exists?(dynamo_table_name(klass[0],@args_before_previous)).should eql false
		end
	end

	it "should retire(decrease throughtput) the given month and year's table in Dynamo DB" do
		Community::DynamoTables::MODERATION_CLASSES.each do |klass| 
			if not dynamo_table_exists?(dynamo_table_name(klass[0], @args_previous))
				Community::DynamoTables.construct(@args_previous)
			end
		end

		Community::DynamoTables.retire(@args_previous)
		Community::DynamoTables::MODERATION_CLASSES.each do |klass|
			table_name = dynamo_table_name(klass[0], @args_previous)
			provisioned_throughput(table_name)[:read_capacity_units].should eql @inactive
			provisioned_throughput(table_name)[:write_capacity_units].should eql @inactive
		end
	end

	it "should delete attachments in s3 with prefix 'spam_attachments' for the given month" do
		@attachment_arr = [{:resource => forum_attachment}]
		time = (Time.now - 5.months)
		folder_name = "spam_attachments/month_#{time.strftime('%Y_%m')}/dynamo_tables_spec/#{Time.now.utc.to_f * (10**7)}"
		store_attachments(folder_name)
		Community::DynamoTables.clear_attachments({:year => time.strftime('%Y'), :month => time.strftime('%m')})
		s3_bucket_objects = AwsWrapper::S3.find_with_prefix(S3_CONFIG[:bucket], "spam_attachments/month_#{time.strftime('%Y_%m')}")
		s3_bucket_objects.collect(&:key).blank?.should eql true
	end
end