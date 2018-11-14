['company_fields_test_helper.rb'].each { |file| require "#{Rails.root}/test/core/helpers/#{file}" }
module CompaniesTestHelper
  def create_company params = {}
    company = FactoryGirl.build(:company, :name => params[:name] || Faker::Name.name )
    company.save
    company
  end

  def company_params_hash(params = {})
    description = params[:description] || Faker::Lorem.paragraph
    custom_field = params[:custom_field] || { "test_custom_text_#{@account.id}" => 'Sample Text' }
    params_hash = { :customers => {
      :name => params[:name] || Faker::Lorem.characters(5),
  	  :account_id => params[:account_id] || Faker::Number.number(1),
      :description => description,
      :sla_policy_id => params[:sla_policy_id] || Faker::Number.number(1),
      :note => params[:note] || Faker::Lorem.characters(5),
      :domains => params[:domains] || Faker::Lorem.characters(5),
      :delta => params[:delta] || Faker::Number.number(1),
      :import_id => params[:import_id] || Faker::Number.number(1),
       }
     }
  end
end
