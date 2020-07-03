# encoding: utf-8
class Helpdesk::ArchiveTicket < ActiveRecord::Base
  include CustomAttributes
  # Custom json used by ES v2
  #
  def to_esv2_json
    custom_attr = account.launched?(:custom_fields_search) ? fetch_custom_attributes : esv2_custom_attributes
    as_json({
      :root => false,
      :tailored_json => true,
      :methods => [
                    :company_id, :tag_names, :tag_ids, :watchers, :status_stop_sla_timer, 
                    :status_deleted, :product_id, :trashed, :es_cc_emails, :es_fwd_emails, 
                    :closed_at, :resolved_at, :to_emails, :spam, :description, :due_by, 
                    :frDueBy, :association_type, :internal_group_id, :internal_agent_id
                  ],
      :only => [
                  :requester_id, :responder_id, :status, :source, :deleted, 
                  :created_at, :updated_at, :account_id, :display_id, :group_id, 
                  :priority, :ticket_type, :subject
                ]
    }, false).merge(custom_attr)
            .merge(attachments: es_v2_attachments).to_json
  end

  # Flexifield denormalized
  #
  def esv2_custom_attributes
    flexifield_column_hash = Flexifield.columns_hash
    # transform boolean fields
    flexifield_data.symbolize_keys.each_with_object({}) do |(field_name, value), hash|
      next unless esv2_ff_columns.include?(field_name)

      hash[field_name] = if flexifield_column_hash[field_name.to_s] && flexifield_column_hash[field_name.to_s].type == :boolean && !value.nil?
                           ([1, true].include? value) ? true : false
                         else
                           value
                         end
    end
  end

  # Flexifield columns supported in V2
  #
  def esv2_ff_columns
    @@esv2_flexi_txt_cols ||= Flexifield.column_names.select { |v| v =~ /^ff/ }.map(&:to_sym)
  end

  # ES v2 specific methods
  #
  def es_v2_attachments
    attachments.pluck(:content_file_name)
  end

  def internal_group_id
    nil
  end

  def internal_agent_id
    nil
  end

  def es_cc_emails
    cc_email_hash[:cc_emails] if cc_email_hash
  end

  def es_fwd_emails
    cc_email_hash[:fwd_emails] if cc_email_hash
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
