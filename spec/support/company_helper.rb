module CompanyHelper

  def company
    @company ||= create_company
  end

  def create_company
    comp = FactoryGirl.build(:company)
    comp.save
    comp
  end

  def fake_a_company
    @company_name = Faker::Company.name.gsub("'","")
    @params = {
      :company       => { 
        :name        => @company_name, 
        :description => Faker::Lorem.sentence, 
        :note        => Faker::Lorem.sentence, 
        :domains     => Faker::Internet.domain_name
      } 
    }
    @company_params = @params.dup
  end

  def fake_a_customer
    @company_name = Faker::Company.name.gsub("'","")
    @params = {
      :customer => {  
        :name        => @company_name, 
        :description => Faker::Lorem.sentence, 
        :note        => Faker::Lorem.sentence, 
        :domains     => Faker::Internet.domain_name
      } 
    }
    @company_params = @params.dup
  end

  def company_attributes company, skipped_keys
    company.attributes.symbolize_keys.except(*skipped_keys)
  end

end