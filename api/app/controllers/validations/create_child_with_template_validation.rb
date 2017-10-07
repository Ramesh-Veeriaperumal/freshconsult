class CreateChildWithTemplateValidation < ApiValidation
  attr_accessor :parent_template_id, :child_template_ids

  validates :parent_template_id, data_type: { rules: Integer }, required: true
  validates :child_template_ids, data_type: { rules: Array }, array: { data_type: { rules: Integer } }, required: true
end
