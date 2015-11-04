class CompanyDecorator
  class << self
    def csv_to_array(input_csv)
      input_csv.nil? ? [] : input_csv.split(',')
    end
  end
end