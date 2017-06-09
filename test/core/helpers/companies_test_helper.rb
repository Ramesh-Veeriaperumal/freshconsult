module CompaniesTestHelper
  def create_company params = {}
    company = FactoryGirl.build(:company, :name => params[:name] || Faker::Name.name)
    company.save
    company
  end
end
