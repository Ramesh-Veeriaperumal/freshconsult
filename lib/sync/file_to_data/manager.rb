class Sync::FileToData::Manager
  include Sync::FileToData::Util
  attr_accessor :root_path, :master_account_id, :account, :failed_records

  def initialize(root_path, master_account_id, retain_id = false, resync = false, clone = false, account = Account.current)
    @root_path = root_path
    @account = account
    @resync = resync
    @clone = clone
    @master_account_id = master_account_id
    @self_associations = []
    @failed_records = {}
    find_model_insert_order
    @push_to_sql = Sync::FileToData::PushToSql.new(root_path, master_account_id, retain_id, resync, clone)
  end

  def update_all_config(action = :added)
    @model_directories = Sync::FileToData::ModelDirectories.new(root_path).perform
    Rails.logger.info("Sandbox model_directories account #{account.id} #{@model_directories.inspect}")
    @model_insert_order.each do |model|
      @model_directories[model].each do |id, model_directories|
        begin
          ActiveRecord::Base.transaction do
            (@model_insert_order & model_directories.keys).each do |_model|
              model_directories[_model].each do |model_directory|
                begin
                  @push_to_sql.perform(_model, model_directory, action)
                rescue Exception => e
                  Sync::Logger.log("Exception during push_to_sql, model: #{_model.inspect}, model_directory #{model_directory.inspect}, action: #{action}, exception: #{e.message}, backtrace: #{e.backtrace[0..5].inspect}")
                end  
              end
            end
          end
        rescue StandardError => e
          Sync::Logger.log("Error Sandbox push data to sql account #{account.id} #{model_directories} #{e.inspect}, #{e.backtrace[0..5].inspect}")
          @failed_records[model] ||= []
          @failed_records[model] << id
        end
      end
      clear_cache(model)
    end
  end

  def post_config
    mapping_table = @push_to_sql.mapping_table
    persist_mapping_table(mapping_table)
    save_failed_records
    Sync::FileToData::PostMigration.new(master_account_id, mapping_table, @push_to_sql.self_associations, @push_to_sql.deleted_associations, @resync).perform
  end

  def affected_tables
    @model_insert_order.map { |table| model_table_mapping[table] }.compact
  end

  private

    def find_model_insert_order
      @model_insert_order = Sync::FileToData::ModelInsertOrder.find
    end

    def clear_cache(model)
      obj = model.constantize.new
      clear_cache_methods = MODEL_MEMCACHE_KEYS[model] || ['clear_cache']
      clear_cache_methods.each do |clear_cache_method|
        next unless obj.respond_to?(clear_cache_method, true)
        Sync::Logger.log("Clearing Cache for : #{model}")
        obj.account_id = Account.current.id if obj.respond_to?('account_id')
        obj.safe_send(clear_cache_method)
      end
    end

    def persist_mapping_table(mapping_table)
      file_path = "#{root_path.gsub(RESYNC_ROOT_PATH, GIT_ROOT_PATH)}/#{MAPPING_TABLE_NAME}#{FILE_EXTENSION}"
      content   = YAML.dump(mapping_table)
      create_file(file_path, content)
    end

    def save_failed_records
      return unless @resync
      Account.current.sandbox_job.additional_data[:failed_records] = failed_records
      Account.current.sandbox_job.save
    end
end
