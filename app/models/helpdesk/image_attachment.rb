# encoding: utf-8

class Helpdesk::ImageAttachment < Helpdesk::Attachment
    before_create :set_content_type, :image?
    before_save :image?

    set_table_name "helpdesk_attachments"
end
