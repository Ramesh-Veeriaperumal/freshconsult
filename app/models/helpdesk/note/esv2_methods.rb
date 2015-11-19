# encoding: utf-8
class Helpdesk::Note < ActiveRecord::Base

  # Custom json used by ES v2
  #
  def to_esv2_json
    as_json({
              :root => false,
              :tailored_json => true,
              :only => [ :notable_id, :deleted, :private, :body, :account_id, :created_at, :updated_at ]
            }).merge(attachments: es_v2_attachments).to_json
  end

  # ES v2 specific methods
  #
  def es_v2_attachments
    attachments.pluck(:content_file_name).collect { |file_name| 
      f_name = file_name.rpartition('.')
      {
        name: f_name.first,
        type: f_name.last
      }
    }
  end
  
  # Used for validating updates/deletes
  #
  def es_v2_valid?
    human_note_for_ticket?
  end

  ##########################
  ### V1 Cluster methods ###
  ##########################

  # _Note_: Will be deprecated and remove in near future
  #
  def to_indexed_json
    as_json({
            :root => "helpdesk/note",
            :tailored_json => true,
            :methods => [ :notable_company_id, :notable_responder_id, :notable_group_id,
                          :notable_deleted, :notable_spam, :notable_requester_id ],
            :only => [ :notable_id, :deleted, :private, :body, :account_id, :created_at, :updated_at ], 
            :include => { 
                          :attachments => { :only => [:content_file_name] }
                        }
            }).to_json
  end
end