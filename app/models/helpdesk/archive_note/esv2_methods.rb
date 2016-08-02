# encoding: utf-8
class Helpdesk::ArchiveNote < ActiveRecord::Base  

    # Custom json used by ES v2
    #
    def to_esv2_json
      as_json({
                :root => false,
                :tailored_json => true,
                :only => [ :deleted, :private, :account_id, :created_at, :updated_at ],
                :methods => [ :body ]
              }).merge(notable_id: archive_ticket_id).merge(attachments: es_v2_attachments).to_json
    end

    # ES v2 specific methods
    #
    def es_v2_attachments
      attachments.pluck(:content_file_name)
    end
end