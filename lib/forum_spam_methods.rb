module ForumSpamMethods
	def self.included(base)
		base.extend(ClassMethods)
		base.send(:include, Community::Moderation::ForumSpamTables)

		base.hash_key(:account_id, :n)
		base.range(:timestamp, :n)

		base.local_secondary_index(:topic_timestamp, :n)
		base.local_secondary_index(:user_timestamp, :n)
		base.provisioned_throughput(base.inactive_capacity, base.write_capacity)
	end

	def account
		return nil unless self[:account_id].present?
		Account.find(self[:account_id])
	end

	def time
		Time.at(self[:timestamp])
	end

	def topic_id
		(topic_timestamp / (10 ** 17)).to_i if self[:topic_timestamp].present?
	end

	def set_timestamp
		@attributes["timestamp"] ||= Time.now.utc.to_f
	end

	def save_changes
		@saved_changes = new_record? ? {} : self.changes
	end

	def body
		Nokogiri::HTML(body_html).text
	end

	def user_id
		(user_timestamp / (10 ** 17)).to_i if self[:user_timestamp].present?
	end

	def user
		User.find(self.user_id) if @attributes['user_timestamp'].present?
	end

	def spam?
		self.class.eql?(ForumSpam)
	end

	def counter
		date = time.strftime('%Y_%m_%d')
		SpamCounter.for(self.type, date)
	end

	def destroy_next
		self.next.destroy unless self.next.blank?
	end

	def into_next_month
		next_month = new_or_find_obj
		next_month.save
		@saved_changes.clear
	end

	def new_or_find_obj
		if @saved_changes.blank?
			next_table.build(self.attributes)
		else
			@saved_changes.each_pair do |k,v|
				next_month[k] = v[:new]
			end
			next_table.find(:account_id => self[:account_id], :timestamp => self[:timestamp])
		end
	end

	def update_counter
		if @saved_changes.blank?
			counter = self.counter
			if self.topic_id
				counter.incr_topic!(self.topic_id)
			else
				counter.incr_new_topic!
			end
		end
	end

	def decr_counter
		counter = self.counter
		if self.topic_id
			counter.decr_topic!(self.topic_id)
		else
			counter.decr_new_topic!
		end
	end

	def destroy_attachments
		#Destroy normal attachments
        AwsWrapper::S3.batch_delete_all(S3_CONFIG[:bucket], self.attachments['folder']) if self.attachments.present?
		#Destroy inline attachments without attachable_id
		DeletedBodyObserver.write_to_s3(self.body_html, 'Post', self.timestamp)
		InlineImageShredder.perform_async({model_name: 'Post', model_id: self.timestamp})
		#Destroy inline attachments
		Account.current.attachments.where(:id => inline_attach_ids).destroy_all
	end

	def inline_attach_ids
		begin
			self.attributes.has_key?('inline_attachment_ids') ? JSON.parse(self.inline_attachment_ids) : []
		rescue JSON::ParserError => e
			[]
		end
	end

	def attachments
		JSON.parse(self[:attachments]) unless self[:attachments].blank?
	end

	def attachments=(hash)
		self[:attachments] = hash.to_json
	end

	module ClassMethods

		def find_post(timestamp)
			find(:account_id => Account.current.id, :timestamp => timestamp)
		end

		def last_month
			query(
				:account_id => Account.current.id, 
				:timestamp => [:gt, (Time.now - ForumSpam::UPTO).utc.to_f],
				:limit => 30
				)
		end

		def next(timestamp)
			query(
				:account_id => Account.current.id, 
				:timestamp => [:ge, (Time.now - ForumSpam::UPTO).utc.to_f],
				:last_record => timestamp,
				:limit => 30
				)
		end

		def topic_spam(topic_id, last = nil)
			query(
				:account_id => Account.current.id, 
				:topic_timestamp => 
					[:between, topic_id.to_i * (10 ** 17) + (Time.now - ForumSpam::UPTO).utc.to_f * (10 ** 7), (topic_id.to_i + 1) * (10 ** 17)],
				:limit => 30,
				:last_record => last
				)
		end

		def delete_topic_spam(topic_id)
			results = topic_spam(topic_id)
			while(results.present?)
				last = results.last_evaluated_key
				results.each do |result|
					result.destroy
				end
				results = topic_spam(topic_id, last)
			end
		end

		def by_user(user, user_timestamp)
			query(
				:account_id => Account.current.id,
				:user_timestamp => 
				[:between, user_timestamp, next_user_timestamp(user)],
				:ascending => true
				)
		end

		def next_user_timestamp(user)
			(user + 1) * (10 ** 17) + Time.now.utc.to_f * (10 ** 7)
		end

	end
end