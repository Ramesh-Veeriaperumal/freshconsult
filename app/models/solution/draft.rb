class Solution::Draft < ActiveRecord::Base

	set_table_name "solution_drafts"

	belongs_to :account
	belongs_to :created_author, :foreign_key => "created_author_id", :class_name => "User"
	belongs_to :current_author, :foreign_key => "current_author_id", :class_name => "User"
	belongs_to :article, :class_name => "Solution::Article"
	
	has_one :draft_body, :class_name => "Solution::DraftBody", :autosave => true, :dependent => :destroy
	has_many_attachments
	has_many_cloud_files

	delegate :description, :to => :draft_body, :allow_nil => true

	validates_uniqueness_of :article_id, :if => 'article_id.present?'

	before_save :populate_defaults
	before_create :populate_created_author

	attr_protected :account_id, :status, :current_author_id, :created_author_id
	alias_attribute :modified_at, :updated_at
	alias_attribute :modified_by, :current_author_id

	STATUSES = [
		[ :editing,     "solutions.draft.status.editing",        0 ], 
		[ :work_in_progress, "solutions.draft.status.work_in_progress",    1 ],
		[ :rework, "solutions.draft.status.rework",    2 ],
		[ :ready_to_publish, "solutions.draft.status.ready_to_publish",    3 ]
	]

	STATUS_OPTIONS	= STATUSES.map { |i| [i[1], i[2]] }
	STATUS_NAMES_BY_KEY	= Hash[*STATUSES.map { |i| [i[2], i[1]] }.flatten]
	STATUS_KEYS_BY_TOKEN	= Hash[*STATUSES.map { |i| [i[0], i[2]] }.flatten]

	COMMON_ATTRIBUTES = ["title", "description"]

	#defining writer methods for delegated attributes
	def description= content
		unless self.draft_body.present?
			self.build_draft_body({:description => content, :account_id => Account.current.id}) and return
		end
		self.draft_body.description = content
	end

	def locked?
		return false unless status == STATUS_KEYS_BY_TOKEN[:editing]
		return false if User.current == current_author
		self.updated_at > (Time.now.utc - 2.hours)
	end

	def lock_for_editing!
		return false if self.locked?
		self.status, self.current_author = STATUS_KEYS_BY_TOKEN[:editing], User.current
		self.save
	end

	def unlock
		self.status = STATUS_KEYS_BY_TOKEN[:work_in_progress]
	end

	def populate_defaults
		self.status ||= STATUS_KEYS_BY_TOKEN[:editing]
		self.current_author ||= User.current
	end

	def populate_created_author
		self.created_author ||= User.current
	end

	def publish!
		COMMON_ATTRIBUTES.each do |attr|
			article.send("#{attr}=", self.send(attr))
		end
		modify_associations
		article.save
		self.reload and self.destroy
	end

	def clone_attachments(parent_article)
		parent_article.attachments.each do |attachment|      
			self.attachments.build(:content => attachment.to_content, :description => "", :account_id => self.account_id)
		end
		parent_article.cloud_files.each do |cloud_file|
  		self.cloud_files.build({:url => cloud_file.url, :application_id => cloud_file.application_id, :filename => cloud_file.filename })
	  end
	end

	def discard_notification(portal)
		unless (User.current == self.created_author && self.created_author.email.present?)
			DraftMailer.send_later(:draft_discard_notification, { :description => self.description, :title => self.title}, 
					self.article, self.created_author, User.current, portal)
		end
	end

	private

		def modify_associations
			[:attachments, :cloud_files].each do |assoc|
				article.send(assoc).destroy_all
				type = self.class.reflections[assoc].options[:as]
				self.send(att).each do |item|
					item.update_attributes(type => article)
				end
			end
		end
end