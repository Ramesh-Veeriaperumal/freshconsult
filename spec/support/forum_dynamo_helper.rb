module ForumDynamoHelper
	TYPE_VALUE_MAPPING = {
		:n => 5,
		:s => Faker::Lorem.words(10).join(" ")
	}

	def create_dynamo_topic(type, forum, opts = {})
		@timestamp = opts[:timestamp]
		obj = type.constantize.build(topic_params(forum).merge!(opts))
		build_attachments(obj) if opts[:attachment]
		obj.save
		type.constantize.find(:account_id => @account.id, :timestamp => @timestamp)
	end

	def create_dynamo_post(type, topic, opts = {})
		@timestamp = opts[:timestamp]
		obj = type.constantize.build(post_params(topic).merge!(opts))
		build_attachments(obj) if opts[:attachment]
		obj.save
		type.constantize.find(:account_id => @account.id, :timestamp => @timestamp)
	end

	def topic_params(forum)
		common_params.merge({
				:forum_id => forum.id,
				:title => Faker::Lorem.sentence
			})
	end

	def post_params(topic)
		common_params.merge({
				:topic_timestamp => topic.id * (10 ** 17) + timestamp * (10 ** 7)
			})
	end

	def common_params
		{
			:timestamp => timestamp, 
			:account_id => @account.id,
			:marked_by_filter => false,
			:portal_id => @account.main_portal.id,
			:user_timestamp => @customer.id * (10 ** 17) + timestamp * (10 ** 7),
			:body_html => "<p>#{Faker::Lorem.paragraph}</p>",
			:cloud_file_attachments => [{:link => "https://www.dropbox.com/s/7d3z51nidxe358m/Getting Started.pdf?dl=0",
																		:name => "Getting Started.pdf",:provider => "dropbox"}.to_json].to_json
		}
	end

	def build_attachments(obj)
		obj.attachments = {
			:file_names => uploaded_attachments,
			:folder => attachment_folder_name
		}
	end

	def forum_attachment
		file = Rack::Test::UploadedFile.new('spec/fixtures/files/image4kb.png','image/png')
		class << file
			attr_reader :tempfile
		end
		file
	end

	def uploaded_attachments
		[{:resource => forum_attachment }].each_with_index.map do |att, i|
			filename = "#{i}_#{att[:resource].original_filename}"
			AwsWrapper::S3Object.store("#{attachment_folder_name}/#{filename}", att[:resource].tempfile, S3_CONFIG[:bucket])
			filename
		end
	end

	def attachment_folder_name
		"spam_attachments/month_#{Time.now.utc.strftime('%Y_%m')}/acc_#{@account.id}}"
	end

	def timestamp
		@timestamp ||= Time.now.utc.to_f	
	end

	def next_user_timestamp(user)
		user.id * (10 ** 17) + (Time.now - ForumSpam::UPTO).utc.to_f * (10 ** 17)
	end

	def user_timestamp_params(user)
		time_stamp = Time.now.utc.to_f
		op = { :timestamp => time_stamp }
		op.merge!({ :user_timestamp =>user.id * (10 ** 17) + time_stamp * (10 ** 7) })
		op
	end

	def delete_dynamo_posts(type)
		res = type.constantize.query(:account_id => @account.id)
		while res.present?
			res.each{|obj| obj.destroy}
			res = type.constantize.query(:account_id => @account.id)
		end
	end

	def build_sample_object(klass)
		obj = klass.new
		klass.all_keys.each do |att|
			obj[att[:name]] = TYPE_VALUE_MAPPING[att[:type]]
			obj[att[:name]] = Time.now.utc.to_i if att[:name] == 'created_at'
		end
		obj
	end

	def create_sample_object(klass)
		obj = build_sample_object(klass)
		obj.save
		obj
	end

	def process_params(options = {})
		{
			"account_id" => @account.id,
			"attachments" => {},
			"cloud_file_attachments" => [{:link => "https://www.dropbox.com/s/7d3z51nidxe358m/Getting Started.pdf?dl=0",
																		:name => "Getting Started.pdf",:provider => "dropbox"}.to_json],
			"body_html" =>  "<p>#{Faker::Lorem.paragraph}</p>",
			"domain" => @account.full_domain,
			"portal" => @account.main_portal.id,
			"request_params" => {
				"user_ip" => "127.0.0.1",
				"referrer" => "http://#{@account.full_domain}/support/discussions/topics/new",
				"user_agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/37.0.2062.94 Safari/537.36"
			},
			"timestamp" => Time.now.utc.to_f,
			"user" => {
				"id" => (options[:user] || @user).id,
				"name" => (options[:user] || @user).name,
				"email" => (options[:user] || @user).email
			}
		}
	end

	def sqs_topic_params(options={})
		process_params(options).merge({
		"topic" => {
				"title" => Faker::Lorem.sentence,
				"forum_id" => @forum.id
			}
		})
	end

	def sqs_post_params(options={})
		process_params(options).merge({
			"topic" => {
				"id" => @topic.id
			}
		})
	end

	def dynamo_table_name(klass, args)
		prefix = klass.table_name.split(Rails.env[0..3]).first
  	%{#{prefix}#{Rails.env[0..3]}_#{(Time.new(args[:year], args[:month])).strftime('%Y_%m')}}
  end

  def dynamo_table_exists?(name)
    begin
      table_data = $dynamo.describe_table(:table_name => name)
      return true
    rescue AWS::DynamoDB::Errors::ResourceNotFoundException => e
      return false
    end
  end

  def provisioned_throughput(name)
    begin
      table_data = $dynamo.describe_table(:table_name => name)
      return table_data[:table][:provisioned_throughput]
    end
  end

  def store_attachments(folder_name)
  	@attachment_arr.each do |att|
			filename = att[:resource].original_filename
			AwsWrapper::S3Object.store("#{folder_name}/#{filename}", att[:resource].tempfile, S3_CONFIG[:bucket])
			filename
		end
  end
end