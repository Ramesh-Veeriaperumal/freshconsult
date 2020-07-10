module Import::Zen::Organization

 class CompanyProp < Import::FdSax
   # element :name
   # element :id, :as => :import_id
   # element :notes, :as => :note
   # element :details, :as => :description
   # element :default, :as => :domains
 end

 def save_organization company_xml
  company_prop = CompanyProp.parse(company_xml)
  company = @current_account.companies.find(:first, :conditions =>['name=? or import_id=?',company_prop.name,company_prop.import_id])
  begin
    unless company
      company_prop.domains = company_prop.domains.split(" ").join(',') if company_prop.domains.present?
      company = @current_account.companies.build(company_prop.to_hash)
      company.account_id = @current_account.id
      unless company.save
        if company.errors.keys.count == 1 && company.errors[:"company_domains.domain"].include?("has already been taken")
          Rails.logger.info "Acc id :: #{@current_account.id} :: Company name :: #{company.name} :: Domains exists"
          company_prop.domains = nil
          company = @current_account.companies.create(company_prop.to_hash)
        end
      end
    else
      company.update_attribute(:import_id , company_prop.import_id)
    end
  rescue Exception => e
    NewRelic::Agent.notice_error(e, {:description => "Zen_import :: acc_id :: #{@current_account.id} :: Company :: #{company_prop.import_id}"})
    puts "Error in Zendesk_import ::#{e.message}\n#{e.backtrace.join("\n")}"
  end
 end

end