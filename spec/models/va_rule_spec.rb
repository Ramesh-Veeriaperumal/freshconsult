require 'spec_helper'

describe VaRule do

  self.use_transactional_fixtures = false

  it "raise error for new VA options without test cases" do
    va = Class.new(VA::TestCase).new # Creating a dynamic class for re-including the modules
    va.count
  end

  3.times do # Doing it thrice, coz of the random choices
    it "should test all VA options with random choices" do
      va = Class.new(VA::TestCase).new # Creating a dynamic class for re-including the modules
      va.check_rules
    end
  end

end