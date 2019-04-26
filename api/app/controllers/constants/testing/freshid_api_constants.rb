module Testing::FreshidApiConstants
  LOAD_OBJECT_EXCEPT = [ :find_organisation_by_id, :find_organisation_by_domain, :find_account_by_id, :find_account_by_domain, 
    :organisation_accounts_by_org_domain, :user_accounts_by_id, :user_accounts_by_email, :find_user_by_id, :find_user_by_email,
    :account_users, :modify_admin_rights, :organisation_admins, :deliver_reset_password_instruction, :create_user_activation_hash ].freeze
end.freeze