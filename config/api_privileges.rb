Authority::Authorization::PrivilegeList.build do
  manage_tickets do
    resource :"ember/bootstrap"
    resource :"ember/ticket", only: [:index]
  end

  delete_contact do
    resource :"ember/contact", only: [:bulk_delete]
  end

	delete_ticket do
		resource :"ember/ticket", only: [:bulk_delete]
	end
end
