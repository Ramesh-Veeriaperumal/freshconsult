class CreateSocialConversationsDynamodb < ActiveRecord::Migration
  shard :all
  def self.up
    include Social::Constants

    [Time.now, Time.now+7.days].each do |time|
      table = "interactions"
      schema = TABLES[table][:schema]
      properties = DYNAMO_DB_CONFIG[table]
      name = Social::DynamoHelper.select_table(table, time)

      Social::DynamoHelper.create_table(name, schema[:hash], schema[:range], properties["start_read_capacity"], properties["write_capacity"])
    end
  end

  def self.down
  end
end
