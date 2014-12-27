require 'spec_helper'

#to do:
#1. try to use table_config in new_table
describe Dynamo do 

	before(:all) do
		$dynamo = AWS::DynamoDB::ClientV2.new
		Dynamo::CLIENT = $dynamo
		
		@table_config = HashWithIndifferentAccess.new({
			:hash => { :name => "id", :type => :n },
			:range => { :name => "created_at", :type => :n},
			:lsi => [{:name => "user_id", :type => :n}],
			:provisioned_throughput => {:read => 1, :write => 1}
		})

		@table_name = "dynamo_test"

		class DynamoTest < Dynamo

			hash_key "id", :n
			range "created_at", :n

			local_secondary_index "user_id", :n

			provisioned_throughput 1, 1

			after_save :incr_user_id

			def self.table_name
				"dynamo_test"
			end

			def incr_user_id
				self.incr!(:user_id)
			end
		end
		DynamoTest.create_table
	end

	after(:all) do 
		DynamoTest.drop_table
	end

	it "should create a new table in Dynamo DB with the proper hash, range and lsis" do

		dynamo_test1 = Class.new(Dynamo) do 

			hash_key "id", :n
			range "created_at", :n

			local_secondary_index "user_id", :n

			provisioned_throughput 1, 1

			def self.table_name
				"dynamo_test1"
			end
		end

		dynamo_test1.create_table.should eql true

		table_schema = $dynamo.describe_table(:table_name => "dynamo_test1")

		table_schema_with_type = table_schema[:table][:attribute_definitions].inject({}) {|h, sch| h[sch[:attribute_name]] = sch[:attribute_type]; h}

		@table_config.values.flatten[0..-2].each do |sch|
			table_schema_with_type.keys.should include(sch[:name])
			table_schema_with_type[sch[:name]].downcase.to_sym.should eql sch[:type]
		end

		dynamo_test1.drop_table
	end

	it "should update the throughput of the given table" do
		DynamoTest.update_throughput(2, 2).should eql true
		updated_throughput = $dynamo.describe_table(:table_name => @table_name)[:table][:provisioned_throughput]
		updated_throughput[:read_capacity_units].should eql 2
		updated_throughput[:write_capacity_units].should eql 2
	end

	it "should build object of the given class, get and set the specified attributes" do
		time = Time.now.utc.to_f
		sample_obj = DynamoTest.build("id" => 1, "created_at" => time, "user_id" => 35)
		sample_obj.class.name.should eql "DynamoTest"
		sample_obj["id"].should eql 1
		sample_obj["created_at"].should eql time
		sample_obj["user_id"].should eql 35
		sample_obj["user_id"] = 26
		sample_obj["user_id"].should eql 26
	end

	it "should detect whether it's a new record or not" do
		new_obj = build_sample_object(DynamoTest)
		new_obj.new_record?.should eql true
		new_obj.save
		new_obj.new_record?.should eql false
	end

	it "should find the proper object, if not found, it should initializ a new object" do
		time = Time.now.utc.to_f
		sample_obj = DynamoTest.find_or_initialize(:id => 1, :created_at => time, :user_id => 25)
		sample_obj.new_record?.should eql true
		sample_obj.save
		sample_obj1 = DynamoTest.find_or_initialize(:id => 1, :created_at => time)
		sample_obj1.new_record?.should eql false
		sample_obj1.attributes.should eql sample_obj.attributes
	end

	it "should save the object in dynamo with the given attributes" do
		new_obj = create_sample_object(DynamoTest)
		saved_obj = DynamoTest.find_or_initialize(:id => new_obj.id, :created_at => new_obj.created_at)
		saved_obj.attributes.should eql new_obj.attributes
	end

	it "should update an object when an attribute is changed and should contain the proper changes" do
		new_obj = create_sample_object(DynamoTest)
		new_obj["user_id"] = new_obj["user_id"]+1
		new_obj.respond_to?(:user_id).should eql true
		new_obj.changes.keys.should include "user_id"
		new_obj.changed?(:user_id).should eql true
		new_obj["topic_id"] = 7
		new_obj.save
	end

	it "should increment the given attributes by 1" do
		new_obj = create_sample_object(DynamoTest)
		user_id = new_obj.user_id
		new_obj.incr!(:user_id)
		new_obj.user_id.should eql user_id+1
	end

	it "should decrement the given attributes by 1" do
		new_obj = create_sample_object(DynamoTest)
		user_id = new_obj.user_id
		new_obj.decr!(:user_id)
		new_obj.user_id.should eql user_id-1
	end

	it "should destroy the given item" do
		sample_obj = create_sample_object(DynamoTest)
		sample_obj.destroy
		DynamoTest.find(:id => sample_obj.id, :created_at => sample_obj.created_at).should eql nil
	end

	it "should return true if table exists" do
		DynamoTest.table_exists?.should eql true
	end

	it "hash key has a value less than the specified value" do
		time = Time.now.utc.to_i
		(0..10).each do |i|
			create_sample_object(DynamoTest)
		end

		fetched_records = DynamoTest.query(:id => 5, :created_at => [:lt, time]).records
		fetched_records.each do |record|
			record.created_at.should < time
		end
	end

	it "should return only the selected attributes" do
		time = Time.now.utc.to_i
		(0..10).each do |i|
			create_sample_object(DynamoTest)
		end
		fetched_record = DynamoTest.query(:id => 5, :created_at => [:lt, time], :select => ["created_at"], :limit => 1).records.first
		fetched_record.attributes.should include "created_at"
		fetched_record.attributes.should_not include "id"
		fetched_record.attributes.should_not include "user_id"
	end

	it "should validate an object if proper values are supplied for hash and range" do
		sample_obj = DynamoTest.build(:id => 6, :created_at => Time.now.utc.to_i)
		sample_obj.valid?.should eql true
	end

	it "should not validate an object if range is declared and is blank" do
		sample_obj = DynamoTest.build(:id => 6)
		sample_obj.valid?.should eql false
		sample_obj.errors["created_at"].should include "Value required"
	end

	it "should not validate an object if the type of value passed is invalid" do
		sample_obj = DynamoTest.build(:id => 6, :created_at => Time.now.utc.to_i, :user_id => "Invalid")
		sample_obj.valid?.should eql false
		sample_obj.errors["user_id"].should include "Invalid Type"
	end

	it "should find an item with the given hash and range attributes" do
		sample_obj = create_sample_object(DynamoTest)
		found_obj = DynamoTest.find(:id => sample_obj.id, :created_at => sample_obj.created_at)
		found_obj.attributes.should eql sample_obj.attributes
	end

	it "should execute the callbacks as specified" do
		sample_obj = build_sample_object(DynamoTest)
		user_id = sample_obj.user_id
		sample_obj.save
		sample_obj.user_id.should eql user_id+1
	end

	it "should destroy the given table" do
		DynamoTest.drop_table.should eql true
		DynamoTest.table_exists?.should eql false
	end
end