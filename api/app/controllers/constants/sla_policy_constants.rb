module SlaPolicyConstants
  ALLOWED_HASH_FIELDS = [{'company_ids' => [nil]} , 'company_ids']

  UPDATE_FIELDS = ['applicable_to'] | ['applicable_to' =>  ALLOWED_HASH_FIELDS]
end
