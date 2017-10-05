class TicketTemplateDecorator < ApiDecorator
  delegate :id, :name, :attachments, :template_data, :description, :data_description_html, :association_type, :cloud_files, :parent_template?, to: :record

  STRING_TO_INTEGER_MAPPING = ['status', 'priority', 'responder_id', 'group_id', 'product_id'].freeze

  TEMPLATE_TO_TICKET_MAPPING =   {
                                  'ticket_type' => 'type'
                                  }.freeze

  def initialize(record, _options)
    super(record)
  end

  def to_full_hash
    to_hash.merge(ticket_template_data)
  end

  def to_hash
    {
      id: id,
      name: name,
      assoc_type: association_type
    }
  end

  def to_hash_and_child_templates
    templt_obj = {}
    templt_obj[:child_templates] = child_templates if parent_template?
    to_hash.merge(templt_obj)
  end

  def attachments_hash
    attachments.map { |a| AttachmentDecorator.new(a).to_hash }
  end

  def cloud_files_hash
    cloud_files.map { |cf| CloudFileDecorator.new(cf).to_hash }
  end

  def child_templates
    templates = []
    record.child_templates.each do |child|
      templates << TicketTemplateDecorator.new(child, {}).to_hash
    end
    templates
  end

  private

    def ticket_template_data
      tkt_obj = {}
      tkt_obj[:description]       = data_description_html
      tkt_obj[:description_text]  = description
      tkt_obj[:custom_fields] = {}
      mapping = Account.current.ticket_field_def.ff_alias_column_mapping
      custom_fields_name_mapping = mapping.each_with_object({}) { |(ff_alias, column), hash| hash[ff_alias] = TicketDecorator.display_name(ff_alias) }
      template_data.each do |k, v|
        v = handle_value_type_change(k, v)
        if custom_fields_name_mapping.key?(k)
          tkt_obj[:custom_fields][custom_fields_name_mapping[k]] = v
        else
          tkt_obj[TEMPLATE_TO_TICKET_MAPPING[k] || k] = v
        end
      end
      tkt_obj[:attachments] = attachments.exists? ? attachments_hash : []
      tkt_obj[:cloud_files] = cloud_files.exists? ? cloud_files_hash : []
      tkt_obj[:child_templates] = child_templates if parent_template?
      tkt_obj
    end

    def handle_value_type_change(k, v)
      return v.to_i if STRING_TO_INTEGER_MAPPING.include?(k) || integer_custom_fields.include?(k)
      v
    end

    def integer_custom_fields
      @integer_custom_fields ||= Account.current.ticket_field_def.integer_ff_aliases
    end
end
