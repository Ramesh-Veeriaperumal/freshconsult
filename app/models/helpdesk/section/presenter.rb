class Helpdesk::Section < ActiveRecord::Base
  include RepresentationHelper

  acts_as_api

  api_accessible :central_publish do |s|
    s.add :id
    s.add :label
    s.add proc { |s| s.associated_picklist_values }, as: :associated_picklist_values
    s.add proc { |s| s.section_field_ids }, as: :section_fields
  end

  def associated_picklist_values
    section_picklist_mappings.map(&:picklist_value).map(&:value)
  end

  def section_field_ids
    section_fields.map(&:ticket_field_id)
  end
  
end
