Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"ember/bootstrap"
  end

  delete_contact do
    resource :"ember/contact", only: [:bulk_delete]
  end
end
