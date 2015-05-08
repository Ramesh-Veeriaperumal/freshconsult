module ApiMethods
  def parse_date(date, date_sym)
    Date.parse(date) if date
  rescue
    self.errors.add(date_sym, "datatype_mismatch")
  end
end