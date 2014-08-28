module CustomMatcher  
  RSpec::Matchers.define :include_all do |expected_attributes|
    match do |actual|
      expected_attributes.all? do |attribute|
        actual.include? attribute
      end
    end
  end 
end
