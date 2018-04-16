module Concerns::CustomerNote::Associations
  extend ActiveSupport::Concern

  included do
    belongs_to_account
    has_many_attachments
    has_one :note_body, class_name: "#{self.name}Body", dependent: :destroy

    accepts_nested_attributes_for :note_body, allow_destroy: true, update_only: true

    has_many :inline_attachments, :class_name => "Helpdesk::Attachment",
                                  :conditions => { :attachable_type => "Note::Inline" },
                                  :foreign_key => "attachable_id",
                                  :dependent => :destroy

    has_many_cloud_files

    attr_accessible :title, :created_by, :last_updated_by, :note_body_attributes
    attr_protected :attachments, :s3_key
  end
end
