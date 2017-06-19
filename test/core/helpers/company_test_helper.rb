module CompanyTestHelper

  def create_company
    comp = FactoryGirl.build(:company)
    comp.save
    comp
  end
end