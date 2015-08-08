module SlaPolicyConstants
  # COMPANY_SLA_ARRAY_FIELDS = [{ 'company_ids' => [] }]
  # COMPANY_SLA_FIELDS= %w(company_ids) | COMPANY_SLA_ARRAY_FIELDS

  ALLOWED_HASH_FIELDS = [{ 'company_ids' => [] }, 'company_ids']

  SLA_UPDATE_FIELDS = ['conditions' =>  ALLOWED_HASH_FIELDS]
end
