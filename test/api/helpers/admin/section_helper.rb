require 'faker'

module Admin::SectionHelper
  def create_section(ticket_field, picklist_ids = [])
    picklist_ids = *picklist_ids
    return false if ticket_field.blank? || !(ticket_field.safe_send(:dropdown_field?) || ticket_field.safe_send(:type_field?))

    ticket_field_choices = ticket_field.list_all_choices
    existing_section_mapping_ids = ticket_field.section_picklist_mappings.map(&:picklist_id)
    choice_to_be_used = (picklist_ids & ticket_field_choices.map(&:picklist_id)) - existing_section_mapping_ids

    return false if choice_to_be_used.blank?

    choices = ticket_field_choices.select { |choice| choice_to_be_used.include?(choice.picklist_id) }
    Account.current.sections.new.tap do |section|
      section.ticket_field_id = ticket_field.id
      section.label = "#{ticket_field.label}_section_#{Faker::Lorem.characters(10)}"
      choices.each do |each_choice|
        section.section_picklist_mappings.build(picklist_value_id: each_choice.id, picklist_id: each_choice.picklist_id)
      end
      section.save!
    end
  end

  def section_position_bad_request_error(ticket_field_label, section_id, max_position)
    {
      code: 'invalid_value',
      field: "#{ticket_field_label}[section_mappings[section_id `#{section_id}`]]",
      message: "Position should be from 1 to #{max_position} inclusive"
    }
  end
end
