class UpdateStrangeNumbersToUsers < ActiveRecord::Migration
  shard :all
  
  STRANGE_NUMBERS = {
    :"+7378742833" => "RESTRICTED", 
    :"+2562533" => "BLOCKED", 
    :"+8656696" => "UNKNOWN",
    :"+266696687"=> "ANONYMOUS",
    :"+17378742833" => "RESTRICTED", 
    :"+12562533" => "BLOCKED", 
    :"+18656696" => "UNKNOWN",
    :"+1266696687"=> "ANONYMOUS",
    :"7378742833" => "RESTRICTED", 
    :"2562533" => "BLOCKED", 
    :"8656696" => "UNKNOWN",
    :"266696687"=> "ANONYMOUS"
  }

  STATE_HASH_FOR_NOTCLOSED = {
    :"active" => 1,
    :"suspended" => 2
  }

  def up
    Freshfone::Account.find_in_batches(:conditions => {:state => STATE_HASH_FOR_NOTCLOSED.values}) { |freshfone_acc|
      freshfone_acc.each{ |acc|
        acc.account.all_users.find_in_batches(:conditions => {:name => STRANGE_NUMBERS.keys}) { |users|
          users.each { |user|
            user.name = STRANGE_NUMBERS[user.name.to_sym]
            user.save!
          }
        }
      }
    }
  end

  def down
    Freshfone::Account.find_in_batches(:conditions => {:state => STATE_HASH_FOR_NOTCLOSED.values}) { |freshfone_acc|
      freshfone_acc.each{  |acc|
        acc.account.all_users.find_in_batches(:conditions => {:name => STRANGE_NUMBERS.values.uniq}) { |users|
          users.each { |user|
            user.name = user.available_number
            user.save!
          }
        }
      }
    }  
  end

end
