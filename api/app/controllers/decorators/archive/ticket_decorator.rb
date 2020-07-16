class Archive::TicketDecorator < TicketDecorator
  include Crypto::TokenHashing

  delegate :ticket_body, :custom_field, :cc_email, :email_config_id, :fr_escalated, :group_id, :priority,
           :requester_id, :responder, :responder_id, :source, :spam, :status, :subject, :display_id, :ticket_type,
           :schema_less_ticket, :deleted, :due_by, :frDueBy, :isescalated, :description,
           :internal_group_id, :internal_agent_id, :association_type, :subsidiary_tkts_count, :can_be_associated?,
           :description_html, :tag_names, :attachments, :attachments_sharable, :company_id, :cloud_files, :ticket_states, :to_emails, :product_id, :company, to: :record

  delegate :multiple_user_companies_enabled?, to: 'Account.current'

  def custom_fields
    custom_fields_hash = {}
    custom_fields_mapping = Account.current.ticket_fields_from_cache.select { |field| field.default == false }.map { |x| [x.name, x.field_type] }.to_h
    custom_field.each do |k, v|
      next if @custom_fields_mapping[k] == Helpdesk::TicketField::CUSTOM_FILE && !private_api?
      
      custom_fields_hash[@name_mapping[k]] = if v.respond_to?(:utc)
                                               if custom_fields_mapping[k] == Helpdesk::TicketField::CUSTOM_DATE_TIME 
                                                 format_date(v, true)
                                               else
                                                 format_date(v)
                                               end
                                             elsif @custom_fields_mapping[k] == Helpdesk::TicketField::CUSTOM_FILE && v.present?
                                               v.to_i
                                             else
                                               v
                                             end
    end
    custom_fields_hash
  end

  def full_hash
    [basic_hash, attachments_hash, associations_hash, meta_hash].inject(&:merge)
  end

  def meta_hash
    meta = {}
    return meta unless Account.current.agent_collision_revamp_enabled?

    meta[:meta] = {
      secret_id: generate_secret_id
    }
    meta
  end

  def generate_secret_id
    mask_id(display_id)
  end

  def basic_hash
    res_hash = {
      cc_emails: cc_email.try(:[], :cc_emails),
      fwd_emails: cc_email.try(:[], :fwd_emails),
      reply_cc_emails: cc_email.try(:[], :reply_cc),
      ticket_cc_emails: cc_email.try(:[], :tkt_cc),
      fr_escalated: fr_escalated,
      spam: spam,
      group_id: group_id,
      priority: priority,
      requester_id: requester_id,
      responder_id: responder_id,
      source: source,
      company_id: company_id,
      status: status,
      subject: subject,
      to_emails: try(:to_emails),
      product_id: try(:product_id),
      id: display_id,
      type: ticket_type,
      due_by: due_by.to_datetime.try(:utc),
      fr_due_by: frDueBy.to_datetime.try(:utc),
      is_escalated: isescalated,
      description: description_html,
      description_text: description,
      custom_fields: custom_fields,
      created_at: created_at.to_datetime.try(:utc),
      updated_at: updated_at.to_datetime.try(:utc),
      tags: tag_names,
      archived: true
    }
    if Account.current.next_response_sla_enabled?
      res_hash[:nr_due_by] = nr_due_by.try(:to_datetime).try(:utc)
      res_hash[:nr_escalated] = nr_escalated.present?
    end
    res_hash
  end

  def attachments_hash
    {
      attachments: attachments.map do |a|
        {
          id: a.id,
          content_type: a.content_content_type,
          size: a.content_file_size,
          name: a.content_file_name,
          attachment_url: a.attachment_url_for_api,
          created_at: a.created_at.to_datetime.try(:utc),
          updated_at: a.updated_at.to_datetime.try(:utc)
        }
      end
    }
  end

  def associations_hash
    hash = {}
    requester_hash = requester
    stats_hash = stats
    company = company_hash 
    conversations_hash = conversations
    hash[:deleted] = deleted if deleted
    hash[:requester] = requester_hash if requester_hash
    hash[:stats] = stats_hash if stats_hash
    hash[:company] = company if company
    hash[:conversations] = conversations_hash if conversations_hash
    if Account.current.shared_ownership_enabled?
      hash[:internal_agent_id] = internal_agent_id
      hash[:internal_group_id] = internal_group_id
    end
    hash
  end

  def conversations
    if @sideload_options.include?('conversations')
      preload_options = [:attachments]
      preload_options << [:schema_less_note, :note_old_body] unless archive_old_conversations?

      ticket_conversations = record.archive_notes.
                             conversations(preload_options, :created_at, ConversationConstants::MAX_INCLUDE)
      ticket_conversations.map { |conversation| Archive::ConversationDecorator.new(conversation, ticket: record).construct_json }
    end
  end

  class << self
    def display_name(name)
      name[0..(-Account.current.id.to_s.length - 2)]
    end
  end

  def archive_old_conversations?
    current_shard = ActiveRecord::Base.current_shard_selection.shard.to_s
    ArchiveNoteConfig[current_shard] && (record.id <= ArchiveNoteConfig[current_shard].to_i)
  end

end
