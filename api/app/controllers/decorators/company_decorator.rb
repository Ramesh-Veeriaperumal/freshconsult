class CompanyDecorator
  class << self
    def csv_to_array(input_csv)
      input_csv.split(',') unless input_csv.nil?
    end
  end
end
