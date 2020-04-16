class AdminEmail::AssociatedAccounts < Dynamo

  MAX_ACCOUNTS_COUNT = 5

  attr_accessor :id, :created_at

  provisioned_throughput(1, 1)
  hash_key(:email, :s)

  def self.table_name
    unless Rails.env.production?
      "admin_email_associated_accounts_#{Rails.env[0..3]}"
    else
      "admin_email_associated_accounts"
    end
  end

  # Find method returns list of accounts for a given email_id from dynamodb.
  # Returned array will have account id & created timestamp info if raw=true
  # Returned array will have array of accounts if raw=false
  # Fetching data from DB, If there is any problem in fetching data from dyanmodb

  def self.find email, raw=false
    begin
      response = CLIENT.get_item(query_hash(email))
    rescue Exception => e
      fetch_from_db email
    else
      return [] if response.count == 0

      # As dynamodb query returns result in List format(AWS::Core::Data::List),
      # converting the response into array.
      associated_accounts_dump = response.item["accounts"][:ss].to_a
      associated_accounts_list = associated_accounts_dump.collect { | res_str | self.new(res_str) }

      return associated_accounts_list if raw

      results = []

      # Get the array of accounts.
      associated_accounts_list.each do | res_str |
        account_id = res_str.id
        begin
          Sharding.select_shard_of(account_id) do
            account = Account.find(account_id)
            # Executing account.host to get host info (using sharding).
            account.host
            results.push(account)
          end
        rescue Exception => e
          next
        end
      end
      results
    end
  end

  def initialize res_str
    @id = res_str.split(',')[0]
    @created_at = res_str.split(',')[1]
  end

  # Returns list of accounts
  def self.fetch_from_db email
    agents = results = []

    Sharding.run_on_all_slaves do
      agents = User.technicians.where(email: email).to_a
      agents.each do |agent|
        agent.account.host
        results.push(agent.account)
      end
    end

    results
  end

  # Update method stores & updates user records in dynamodb.

  def self.update email, account_id, time_stamp
    CLIENT.update_item(query_hash(email).merge({
      attribute_updates: {
        "accounts" => {
          value: {
            "SS" => ["#{account_id},#{time_stamp}"]
          },
          action: DYNAMO_ACTIONS[:add]
        }
      }
    }))
  end

  def self.remove email, account_id, time_stamp
    CLIENT.update_item(query_hash(email).merge({
      attribute_updates: {
        "accounts" => {
          value: {
            "SS" => ["#{account_id},#{time_stamp}"]
          },
          action: "DELETE"
        }
      }
    }))
  end

  private
    def self.query_hash email
      {
        table_name: table_name,
        key: {
          "email" => {
            "S" => email
          }
        }
      }
    end

end
