class AwsWrapper::DynamoDb
  attr_accessor :table

  #For all calls in this wrapper we are using API v2
  #This API call needs to be changed if aws-sdk is upgraded
  def initialize(table_name)
    @table = table_name
    @dynamo_db_client = AWS::DynamoDB::ClientV2.new()
    @query_options = {
      :table_name => table_name
    }
  end

  def write(query_options)
    @dynamo_db_client.put_item(merge_options(query_options))
  end

  def query(query_options)
    @dynamo_db_client.query(merge_options(query_options))
  end

  def delete_item(query_options)
    @dynamo_db_client.delete_item(query_options)
  end

  def query_delete_facebook(page_id,timestamp)
    query_delete = {
        :key => {
          "page_id" => {
            "n" => "#{page_id}"
          },
          "timestamp" => {
            "n" => "#{timestamp}"
          }
        }
      }
      delete_item(merge_options(query_delete))
  end

  private
  
  def merge_options(query_options)
    @query_options.merge(query_options)
  end

end