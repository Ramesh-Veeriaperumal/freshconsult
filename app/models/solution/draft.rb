class Solution::Draft < ActiveRecord::Base

	self.table_name = "solution_drafts"
	self.primary_key = :id
	serialize :meta, Hash

	belongs_to_account
	belongs_to :user
	belongs_to :article, :class_name => "Solution::Article"
	
	has_one :draft_body, :class_name => "Solution::DraftBody", :autosave => true, :dependent => :destroy
	has_many_attachments
	has_many_cloud_files

	delegate :description, :to => :draft_body, :allow_nil => true

	validates_uniqueness_of :article_id, :if => 'article_id.present?'

	before_save :populate_defaults
	before_destroy :discard_notification

	attr_protected :account_id, :status, :user_id
	attr_accessor :discarding

	alias_attribute :modified_by, :user_id

	STATUSES = [
		[ :editing,     "solutions.draft.status.editing",        0 ], 
		[ :work_in_progress, "solutions.draft.status.work_in_progress",    1 ]
		# [ :rework, "solutions.draft.status.rework",    2 ],
		# [ :ready_to_publish, "solutions.draft.status.ready_to_publish",    3 ]
	]

	# STATUS_OPTIONS	= STATUSES.map { |i| [i[1], i[2]] }
	# STATUS_NAMES_BY_KEY	= Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
	STATUS_KEYS_BY_TOKEN	= Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]

	LOCKDOWN_PERIOD = 2.hours

	COMMON_ATTRIBUTES = ["title", "description"]

	#defining writer method for delegated attribute
	def description= content
		unless self.draft_body.present?
			self.build_draft_body({:description => content, :account_id => Account.current.id}) and return
		end
		self.draft_body.description = content
	end

	def locked?
		return false unless status == STATUS_KEYS_BY_TOKEN[:editing]
		return false if User.current.id == self.user_id
		self.updated_at > (Time.now.utc - LOCKDOWN_PERIOD)
	end

	def lock_for_editing!
		return false if self.locked?
		self.status, self.user = STATUS_KEYS_BY_TOKEN[:editing], User.current
		save
	end

	def unlock
		self.status = STATUS_KEYS_BY_TOKEN[:work_in_progress]
	end

	def populate_defaults
		self.status ||= STATUS_KEYS_BY_TOKEN[:work_in_progress]
		self.user ||= User.current
		self.modified_at = Time.now.utc unless self.modified_at_changed?
	end

	def publish!
		COMMON_ATTRIBUTES.each do |attr|
			article.send("#{attr}=", self.send(attr))
		end

		move_attachments
		article.status = article.class::STATUS_KEYS_BY_TOKEN[:published]
		# article.modified_by = User.current.id
		article.save
		self.reload
		self.destroy
	end

	def discard_notification
		return unless discarding && (User.current.id != self.user_id && self.user.email.present?)

		portal = Portal.current || Account.current.main_portal
		DraftMailer.send_later(
			:discard_notification, 
			{ :description => self.description, :title => self.title}, 
			self.article, self.user, User.current, portal
		)

	end

	def updation_timestamp
		draft_body.present? ? [updated_at, draft_body.updated_at].max.to_i : 0
	end

	def deleted_attachments type
		(meta[:deleted_attachments] || {})[type] || []
	end

	private

		def move_attachments
			[:attachments, :cloud_files].each do |assoc|
				article.send(assoc).where( :id => self.deleted_attachments(assoc) ).destroy_all
				self.send(assoc).each do |item|
					item.update_attributes(item.object_type => article)
				end
			end
		end
end