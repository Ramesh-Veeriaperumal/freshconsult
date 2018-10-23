class Sync::DataToFile::Manager
  attr_accessor :root_path, :base_config, :associations, :account, :sandbox, :transformer, :sandbox
  include Sync::DataToFile::Util
  def initialize(root_path, master_account_id, config, associations = [], sandbox = false, account = Account.current)
    raise IncorrectConfigError unless account.respond_to?(config)

    @account = account
    @root_path = root_path
    @base_config = config
    @associations = associations
    @sandbox = sandbox
    @mapping_table = {}
    @mapping_table = load_mapping_table(root_path) if sandbox
    @transformer = Sync::DataToFile::Transformer.new(@mapping_table, master_account_id)
  end

  def write_config
    return if sandbox && IGNORE_RELATIONS_TO_PRODUCTION.include?(self.base_config)
    # Delete the records which was sync before an it was deleted after sync
    Sync::DataToFile::Delete.new(sandbox, transformer).prune_deleted_rows(root_path, account, base_config)
    Sync::DataToFile::SaveFiles.new(sandbox, transformer).dump_object_and_associations(root_path, account, base_config, associations)
  end

  class IncorrectConfigError < StandardError
  end
end
