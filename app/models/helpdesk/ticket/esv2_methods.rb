# encoding: utf-8
class Helpdesk::Ticket < ActiveRecord::Base

  # Trigger push to ES only if ES fields updated
  #
  def esv2_fields_updated?
    (@model_changes.keys & esv2_columns).any?
  end
  
  # Columns to observe for model_changes
  #
  def esv2_columns
    @@esv2_columns ||= [:subject, :description, :requester_id, :to_emails, :cc_email, :priority, 
                      :status, :ticket_type, :responder_id, :group_id, :source, :due_by, 
                      :frDueBy, :spam, :deleted, :product_id, :status_stop_sla_timer, :status_deleted
                    ].concat(esv2_ff_columns)
  end

  # Flexifield columns supported in V2
  #
  def esv2_ff_columns
    @@es_flexi_txt_cols ||= Flexifield.column_names.select { |v| v =~ /^ff/ }.map(&:to_sym)
  end

  # Custom json used by ES v2
  #
  def to_esv2_json
    as_json({
      :root => false,
      :tailored_json => true,
      :methods => [
                    :company_id, :tag_names, :tag_ids, :watchers, :status_stop_sla_timer, 
                    :status_deleted, :product_id, :trashed, :attachment_names,
                    :es_cc_emails, :es_fwd_emails
                  ],
      :only => [
                  :requester_id, :responder_id, :status, :source, :spam, :deleted, 
                  :created_at, :updated_at, :account_id, :display_id, :group_id, :due_by, 
                  :frDueBy, :priority, :ticket_type, :subject, :description, :resolved_at, 
                  :closed_at, :to_emails
                ]
    }, false).merge(esv2_custom_attributes).to_json
  end

  # Flexifield denormalized
  #
  def esv2_custom_attributes
    flexifield.as_json(root: false, only: esv2_ff_columns)
  end

  # ES v2 specific methods
  #
  def attachment_names
    attachments.map(&:content_file_name)
  end

  #############################
  ### Count Cluster methods ###
  #############################

  # Used for count cluster currently
  # _Note_: Might be deprecated and removed in near future
  #
  def to_es_json
    as_json({
      :root => false,
      :tailored_json => true,
      :methods => [
                    :company_id, :tag_names, :tag_ids, :watchers, :status_stop_sla_timer, 
                    :status_deleted, :product_id, :trashed
                  ],
      :only => [
                  :requester_id, :responder_id, :status, :source, :spam, :deleted, 
                  :created_at, :updated_at, :account_id, :display_id, :group_id, :due_by, 
                  :frDueBy, :priority, :ticket_type
                ]
    }, false).merge(custom_attributes).to_json
  end

  def tag_names
    tags.map(&:name)
  end

  def tag_ids
    tags.map(&:id)
  end

  def watchers
    subscriptions.map(&:user_id)
  end

  def status_stop_sla_timer
    ticket_status.stop_sla_timer
  end

  def status_deleted
    ticket_status.deleted
  end

  def custom_attributes
    flexifield.as_json(root: false, only: Flexifield.column_names.select {|v| v =~ /^ffs_/})
  end

  ##########################
  ### V1 Cluster methods ###
  ##########################
  
  # _Note_: Will be deprecated and removed in near future
  #
  def search_fields_updated?
    attribute_fields = ["subject", "description", "responder_id", "group_id", "requester_id",
                       "status", "spam", "deleted", "source", "priority", "due_by", "to_emails", "cc_email"]
    include_fields = es_flexifield_columns
    all_fields = attribute_fields | include_fields
    (@model_changes.keys.map(&:to_s) & all_fields).any?
  end

  # _Note_: Will be deprecated and removed in near future
  #
  def to_indexed_json
    as_json({
            :root => "helpdesk/ticket",
            :tailored_json => true,
            :methods => [ :company_id, :es_from, :to_emails, :es_cc_emails, :es_fwd_emails],
            :only => [ :display_id, :subject, :description, :account_id, :responder_id,
                       :group_id, :requester_id, :status, :spam, :deleted, :source, :priority, :due_by,
                       :created_at, :updated_at ],
            :include => { :flexifield => { :only => es_flexifield_columns },
                          :attachments => { :only => [:content_file_name] },
                          :ticket_states => { :only => [ :resolved_at, :closed_at, :agent_responded_at,
                                                         :requester_responded_at, :status_updated_at ] }
                        }
            },
            false).to_json
  end

  # _Note_: Will be deprecated and removed in near future
  #
  def es_flexifield_columns
    @@es_flexi_txt_cols ||= Flexifield.column_names.select {|v| v =~ /^ff(s|_text|_int|_decimal)/}
  end

  ###                                                         ###
  #=> Should bring in ticket_elastic_search_methods.rb here?? <=#
  ###                                                         ###

end