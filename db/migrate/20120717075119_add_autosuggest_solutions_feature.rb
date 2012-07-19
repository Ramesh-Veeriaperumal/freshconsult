class AddAutosuggestSolutionsFeature < ActiveRecord::Migration
def self.up
  	Account.all.each do |account|
      account.features.auto_suggest_solutions.create 
    end
end

def self.down
  	Account.all.each do |account|
  		account.features.auto_suggest_solutions.destroy 
	end
end
end
