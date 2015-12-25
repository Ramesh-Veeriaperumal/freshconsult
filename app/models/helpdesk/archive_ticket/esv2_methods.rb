# encoding: utf-8
class Helpdesk::ArchiveTicket < ActiveRecord::Base

  # Custom json used by ES v2
  #
  def to_esv2_json
    as_json({
      :root => false,
      :tailored_json => true,
      :methods => [
                    :company_id, :tag_names, :tag_ids, :watchers, :status_stop_sla_timer, 
                    :status_deleted, :product_id, :trashed, :es_cc_emails, :es_fwd_emails, 
                    :closed_at, :resolved_at, :to_emails, :spam
                  ],
      :only => [
                  :requester_id, :responder_id, :status, :source, :deleted, 
                  :created_at, :updated_at, :account_id, :display_id, :group_id, :due_by, 
                  :frDueBy, :priority, :ticket_type, :subject, :description
                ]
    }, false).merge(esv2_custom_attributes)
            .merge(attachments: es_v2_attachments).to_json
  end

  # Flexifield denormalized
  #
  def esv2_custom_attributes
    flexifield_data.symbolize_keys.select { |field_name, value| esv2_ff_columns.include?(field_name) }
  end

  # Flexifield columns supported in V2
  #
  def esv2_ff_columns
    @@es_flexi_txt_cols ||= Flexifield.column_names.select { |v| v =~ /^ff/ }.map(&:to_sym)
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

  def es_cc_emails
    cc_email_hash[:cc_emails] if cc_email_hash
  end

  def es_fwd_emails
    cc_email_hash[:fwd_emails] if cc_email_hash
  end
  
  def company_id
    requester.company_id if requester
  end

  def tag_names
    tags.map(&:name)
  end

  def tag_ids
    tags.map(&:id)
  end

  def watchers
    subscription_data.map { |watcher| watcher['user_id'] }
  end

  def status_stop_sla_timer
    ticket_status.stop_sla_timer
  end

  def status_deleted
    ticket_status.deleted
  end
end