require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'provision_sandbox_test_helper.rb')
require Rails.root.join('test', 'api', 'sidekiq', 'sandbox', 'transform_sandbox_helper.rb')
module MergeHelper
  include TransformSandboxHelper
  include ProvisionSandboxTestHelper
  ASSOCIATIONS_NAME_MAPPINGS = {
      "va_rules" => "acccount_va_rules"
  }
  IGNORE_ASSOCIATIONS = ["agents"]
  IGNORE_COLUMNS = ["id", "updated_at" , "created_at", "account_id", "content_updated_at", "attachment_id", "model", "action", "position"]
  def compare_data(data, account)
    @model_table_mapping = model_table_mapping
    ["create", "update", "delete"].each do|action|
      send("compare_#{action}d_data", data, account)
    end
  end

  def  compare_created_data( data, account)
    mapping_table = load_mapping_table(account.id)
    data.each do|association, records|
      next if IGNORE_ASSOCIATIONS.include?(association)
      added_records = records.select{|x| x["action"] == "added"}
      added_records.each do|record|
        model = record["model"]
        next unless record["id"].present? and mapping_table[model].present?
        id = mapping_table[model][:id][record["id"]]
        next unless id.present?
        production_data = find_object(model, id)
        match_json(production_data , record, model)
      end
    end
  end

  def match_json(json1, json2, model)
    json1.each do|key, value|
      associations = (MODEL_DEPENDENCIES[model] || []).map{|x| x[1] } || []
      next if (IGNORE_COLUMNS.include?(key) || (serialized_keys(model)+associations).include?(key))
      puts "#{value == json2[key]}  #{value} #{json2[key]} #{key} #{model} "
      assert_equal value, json2[key]
    end
  end

  def serialized_keys(model)
    model.constantize.serialized_attributes.keys
  end

  def find_object(model, id)
    object = model.constantize.find(id)
    data = object.attributes
    if TRANSFORMATIONS.include?(model)
      column = TRANSFORMATIONS[model]
      data[column] = change_custom_field_name(data[column], @production_account.id, @sandbox_account_id)
    end
    data
  end

  def sql_select_query(account_id, table_name,model,  id)
    sql = "select * from #{table_name} where account_id = #{account_id} and id = #{id}"
    sql += " and deleted = 0" if model.respond_to?('deleted') # soft delete
    ActiveRecord::Base.connection.exec_query(sql).to_hash
  end

  def compare_deleted_data( data, account)
    data.each do|association,records |
      deleted_records = records.select{|x| x["action"] == "deleted"}
      deleted_records.each do|record|
        table_name = @model_table_mapping[record["model"]]
        model = record["model"]
        data = sql_select_query(account.id, table_name, model.constantize, record["id"])
        assert_equal data, []
      end
    end
  end

  def compare_updated_data( data, account)
    data.each do|association, records|
      updated_records = records.select{|x| x["action"] == "modified"}
      updated_records.each do|record|
        model = record["model"]
        data = find_object(model, record["id"])
        match_json(record,data,  model)
      end
    end
  end

  def load_mapping_table(account_id)
    path =  "#{Rails.root}/tmp/sandbox/#{account_id}/"
    YAML.load(File.read("#{path}/mapping_table.txt"))
  end

end