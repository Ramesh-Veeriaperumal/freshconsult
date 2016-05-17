class AdminEmail::AssociatedAccounts < Dynamo

  MAX_ACCOUNTS_COUNT = 5

  provisioned_throughput(1, 1)
  hash_key(:email, :s)

  def self.table_name
    unless Rails.env.production?
      "admin_email_associated_accounts_#{Rails.env[0..3]}"
    else
      "admin_email_associated_accounts"
    end
  end

  def self.find email
    results = CLIENT.get_item(query_hash(email))
    results.count > 0 ? results.item['accounts'].ss.map { |key| { key.split(',')[0] =>  key.split(',')[1]} } : {}
  end

  def self.new email, account_id, time_stamp
    CLIENT.update_item(query_hash(email).merge({
      attribute_updates: {
        "accounts" => {
          value: {
            "SS" => ["#{account_id},#{time_stamp}"]
          },
          action: "ADD"
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
