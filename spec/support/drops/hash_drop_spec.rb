RSpec.describe HashDrop do

  before(:all) do
    @options = { sample_html: "<b> #{Faker::Name.name} </b>",
                 sample_text: "#{Faker::Name.name}",
                 sample_array: ["<b> #{Faker::Name.name} </b>", "<b> #{Faker::Name.name} </b>", "<b> #{Faker::Name.name} </b>"],
                 sample_hash: {
                    key1: "<b> #{Faker::Name.name} </b>",
                    key2: "<b> #{Faker::Name.name} </b>",
                    key3: {
                    key4: "<b> #{Faker::Name.name} </b>", 
                    key5: "<b> #{Faker::Name.name} </b>"
                    }
                  } }
    @hash_drop = HashDrop.new(@options)
  end

  it "should return escape html from string" do
    @hash_drop[:sample_text].should be_eql(@options[:sample_text])
    @hash_drop[:sample_html].should_not =~ /<b>/
    @hash_drop[:sample_html].should_not =~ /<\/b>/
    @hash_drop[:sample_html].should eql(CGI::escapeHTML(@options[:sample_html]))

  end

  it "should escape html from array" do 
    @hash_drop[:sample_array].class.to_s.should eql "Array"
    @hash_drop[:sample_array].each_with_index do |escaped_html,index|
      escaped_html.should_not =~ /<b>/
      escaped_html.should_not =~ /<\/b>/
      escaped_html.should eql(CGI::escapeHTML(@options[:sample_array][index]))
    end
  end

  it "should escape html from nested hash" do 
    @hash_drop[:sample_hash].class.to_s.should eql "Hash"
    @hash_drop[:sample_hash].each do |key,value|
      if value.is_a?(Hash)
        value.each do |k,v|
          v.should_not =~ /<b>/
          v.should_not =~ /<\/b>/
          v.should eql(CGI::escapeHTML(@options[:sample_hash][key][k]))
        end
      else
        value.should_not =~ /<b>/
        value.should_not =~ /<\/b>/
        value.should eql(CGI::escapeHTML(@options[:sample_hash][key]))
      end
    end
  end
  
end