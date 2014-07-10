module Import::Zen::Organization

 class CompanyProp < Import::FdSax
   element :name
   element :id , :as => :import_id
   element :details
 end

 def save_organization company_xml
  company_prop = CompanyProp.parse(company_xml)
  company = @current_account.customers.find(:first, :conditions =>['name=? or import_id=?',company_prop.name,company_prop.import_id])
  unless company
    company = @current_account.customers.create(company_prop.to_hash)
  else
    company.update_attribute(:import_id , company_prop.import_id )
  end
end

end