class ApiCompaniesDecorator < SimpleDelegator

  def csv_to_array
    self.domains.split(',') unless self.domains.nil?
  end
end