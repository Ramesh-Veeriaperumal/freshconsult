module ApiCompanyHelper
  def create_company(options = {})
    account = @account || Account.current
    name = options[:name] || Faker::Name.name
    company = FactoryGirl.build(:company, name: name)
    company.account_id = account.id
    company.created_at = options[:created_at] if options.key?(:created_at)
    company.domains = options[:domains].join(',') if options.key?(:domains)
    company.health_score = options[:health_score] if options.key?(:health_score)
    company.account_tier = options[:account_tier] if options.key?(:account_tier)
    company.industry = options[:industry] if options.key?(:industry)
    company.renewal_date = options[:renewal_date] if options.key?(:renewal_date)
    company.custom_field = options[:custom_fields] if options.key?(:custom_fields)
    company.save!
    company.reload
  end
end
