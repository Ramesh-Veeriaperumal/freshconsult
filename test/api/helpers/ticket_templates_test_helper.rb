[ 'attachments_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
module TicketTemplatesTestHelper
  include AttachmentsTestHelper

  def private_api_prime_templates_index_pattern
    pattern_array = Account.current.prime_templates.order(:name).map do |template|
      index_pattern template
    end
  end

  def private_api_ticket_templates_index_pattern
    pattern_array = Account.current.ticket_templates.where(association_type: Helpdesk::TicketTemplate::ASSOCIATION_TYPES_KEYS_BY_TOKEN[:general]).order(:name).map do |template|
      index_pattern template
    end
  end

  def index_pattern(template)
    {
      id: template.id,
      name: template.name,
      assoc_type: template.association_type,
      type: 'shared',
      source: template.template_data.try(:[], :source)
    }
  end

  def to_hash_pattern(template = @template)
    {
      id: template.id,
      name: template.name,
      assoc_type: template.association_type
    }
  end

  def private_api_show_pattern
    to_hash_pattern(@template).merge(ticket_template_data)
  end

  def ticket_template_data
    template_data = {
      description: @template.data_description_html,
      description_text: @template.description,
      custom_fields: {}
    }.merge(template_custom_fields).merge(attachments: @template.attachments.map do |attachment|
                                                         attachment_pattern(attachment)
                                                       end,
                                          cloud_files: [])
    template_data[:child_templates] = child_templates if @template.parent_template?
    template_data.stringify_keys!
  end

  def to_hash_and_child_template_pattern
    templt_obj = {}
    templt_obj[:child_templates] = child_templates if @template.parent_template? 
    to_hash_pattern(@template).merge(templt_obj)
  end

  private

    def child_templates
      templates = []
      @template.child_templates.each do |child|
        templates << to_hash_pattern(child)
      end
      templates
    end

    def template_to_ticket_mapping
      {
        'ticket_type' => 'type'
      }
    end

    def template_custom_fields
      tkt_obj = {}
      other_fields_mapping = template_to_ticket_mapping
      mapping = Account.current.ticket_field_def.ff_alias_column_mapping
      custom_fields_name_mapping = mapping.each_with_object({}) { |(ff_alias, column), hash| hash[ff_alias] = TicketDecorator.display_name(ff_alias) }
      @template.template_data.each do |k, v|
        v = handle_value_type_change(k, v)
        if custom_fields_name_mapping.key?(k)
          tkt_obj[:custom_fields][custom_fields_name_mapping[k]] = v
        elsif other_fields_mapping.key?(k)
          tkt_obj[other_fields_mapping[k]] = v
        else
          tkt_obj[k] = v
        end
      end
      tkt_obj.stringify_keys!
    end

    def handle_value_type_change(k, v)
      if string_to_integer_mapping.key?(k) || integer_custom_fields.include?(k)
        v.to_i
      elsif string_to_array_mapping.key?(k)
        v.split(',')
      else
        v
      end
    end

    def integer_custom_fields
      @integer_custom_fields ||= Account.current.ticket_field_def.integer_ff_aliases
    end

    def string_to_integer_mapping
      {
        'status'        => true,
        'priority'      => true,
        'responder_id'  => true,
        'group_id'      => true,
        'product_id'    => true
      }
    end

    def string_to_array_mapping
      {
          'tags' => true
      }
    end
end
