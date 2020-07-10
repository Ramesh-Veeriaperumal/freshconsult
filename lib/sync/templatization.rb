class Sync::Templatization
  include Sync::Templatization::Constant
  include Sync::Util
  include Sync::Constants
  include Sync::Templatization::MetaInfo

  attr_accessor :account, :sandbox_account_id, :diff_changes, :root_path, :sandbox_root_path, :resync_root_path, :action, :repo_client

  def initialize(diff_changes, sandbox_account_id, account = Account.current)
    @account            = account
    @diff_changes       = diff_changes
    @sandbox_account_id = sandbox_account_id
    @root_path          = "#{GIT_ROOT_PATH}/#{account.id}"
    @sandbox_root_path  = "#{GIT_ROOT_PATH}/#{sandbox_account_id}"
    @resync_root_path   = "#{RESYNC_ROOT_PATH}/#{account.id}"
    @repo_client        = Rugged::Repository.new("#{root_path}/.git")
    @action             = nil
    @transformer        = Sync::DataToFile::Transformer.new({}, account.id)
  end

  def build_delta
    @delta = {}
    (MERGE_FILES_TYPES + [:conflict]).each do |type|
      next unless diff_changes[type]
      create_config_files(diff_changes[type], root_path, account.id)
      @action = type
      RELATIONS.each do |relation|
        changes_for_model(resync_root_path, relation[0])
      end
    end
    FileUtils.rm_rf(resync_root_path)
    {}.tap { |r| @delta.each { |k, v| r[k] = v.values.compact } } # Consolidate
  end

  private

    def changes_for_model(path, association)
      dir_path = "#{path}/#{association}"
      return {} unless File.directory?(dir_path)
      if ['contact_form', 'company_form'].include?(association)
        object = account.class.reflections[association.to_sym].klass.new
        dir_path = "#{dir_path}/" + Dir.entries(dir_path).select { |item| item.to_i > 0 }.first + '/all_fields'
        changes_for_each_record(dir_path, object, association)
      else
        changes_for_each_record(dir_path, account, association)
      end
    end

    def changes_for_each_record(dir_path, base_object, association)
      return if IGNORE_ASSOCIATIONS_LIST.include?(association)
      @delta[association] ||= {}
      return unless File.directory?(dir_path)
      traverse_directory(dir_path) do |item|
        object_path = "#{dir_path}/#{item}"
        initialize_delta(association, item, object_path)
        @delta[association][item][:changes] += changes_for_each_record_util(object_path, base_object)
      end
    end

    def initialize_delta(association, item, object_path)
      @delta[association][item] ||= {}
      @delta[association][item] = construct_meta_info(object_path, association)
    end

    def changes_for_each_record_util(path, object)
      return [] unless File.directory?(path)
      changes = []
      association = File.basename(File.dirname(path))
      return [] if IGNORE_ASSOCIATIONS_LIST.include?(association)
      if association.gsub(/.*_([^_]+)$/, '\1').to_i.zero?
        object   = object.class.reflections[association.to_sym].klass.new # send(association).new
        changes += generate_delta_changes(path, object)
      end
      traverse_directory(path) do |item|
        object_path = "#{path}/#{item}"
        if File.directory?(object_path)
          changes += changes_for_each_record_util(object_path.to_s, object)
        end
      end
      changes
    end

    def model_name(object)
      model = object.class.superclass.to_s != 'ActiveRecord::Base' ? object.class.superclass.to_s : object.class.name
      model = 'VaRule' if model == 'VARule'
      model
    end

    def generate_delta_changes(path, object)
      changes = []
      traverse_directory(path) do |item|
        object_path = "#{path}/#{item}"
        if File.file?(object_path)
          git_path = object_path.gsub("#{resync_root_path}/", '')
          next if ignore_column?(git_path, model_name(object))
          changes << send("#{action}_template", object_path, git_path).merge!(status: action)
        end
      end
      changes
    end

    def ignore_column?(path, model)
      column_name = path.split('/')[-1].gsub(FILE_EXTENSION, '')
      GLOBAL_IGNORE_COLUMNS.include?(column_name) || (INGNORE_COLUMNS_BY_MODEL[model] || []).include?(column_name)
    end

    def construct_meta_info(path, association)
      id = File.basename(path)
      unless @delta[association][id].empty?
        @delta[association][id][:status] = action == :conflict ? :conflict : :modified
        return @delta[association][id]
      end
      object = account.class.reflections[association.to_sym].klass.new
      {
        id: id,
        status: status_name(path, association),
        changes: [],
        meta: begin_rescue { send("#{model_name(object).gsub('::', '').snakecase}_meta_info", path) }
      }
    end

    def status_name(path, association)
      return action if [:modified, :conflict].include?(action)
      file_path = File.join(path, default_column(association))
      return :deleted unless  File.exist?(replace_resync_with_root_path(file_path))
      File.exist?(file_path) ? :added : :modified
    end

    def default_column(association)
      association == 'tags' ? "name.txt" : "created_at.txt"
    end

    def added_template(path, git_path)
      {
        key: path.gsub("#{resync_root_path}/", '').gsub(FILE_EXTENSION, ''),
        production_value: load_yaml_from_hash(diff_changes[action][git_path][1])
      }
    end

    def deleted_template(path, git_path)
      {
        key: path.gsub("#{resync_root_path}/", '').gsub(FILE_EXTENSION, ''),
        production_value: load_yaml_from_hash(diff_changes[action][git_path][0])
      }
    end

    def modified_template(path, git_path)
      {
        key: path.gsub("#{resync_root_path}/", '').gsub(FILE_EXTENSION, ''),
        production_value: load_yaml_from_hash(diff_changes[action][git_path][0]),
        sandbox_value: load_yaml_from_hash(diff_changes[action][git_path][1])
      }
    end

    def conflict_template(path, git_path)
      {
        key: path.gsub("#{resync_root_path}/", '').gsub(FILE_EXTENSION, ''),
        production_value: load_yaml_from_hash(diff_changes[action][git_path][0]),
        sandbox_value: load_yaml_from_hash(diff_changes[action][git_path][1]),
        ancestor_value: load_yaml_from_hash(diff_changes[action][git_path][2])
      }
    end

    def replace_resync_with_root_path(dir_path)
      dir_path.gsub(resync_root_path, root_path)
    end

    def replace_resync_with_sandbox_root_path(dir_path)
      dir_path.gsub(resync_root_path, sandbox_root_path)
    end

    def load_yaml_from_hash(hash_id)
      return unless hash_id
      content = repo_client.lookup(hash_id).content
      Syck.load(content) if content
    end

    def begin_rescue
      yield
    rescue Exception => e
      Sync::Logger.log("Sandbox resync templatization  account id #{account.id} \n#{e}\n#{e.backtrace[0..7].inspect}")
      nil
    end

    def select_shard_and_slave(account_id, &_block)
      begin_rescue do
        Sharding.select_shard_of(account_id) do
          Sharding.run_on_slave do
            @acc = Account.find(account_id).make_current
            yield
          end
        end
      end
    end
end
