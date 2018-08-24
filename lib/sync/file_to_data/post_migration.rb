class Sync::FileToData::PostMigration
  include Sync::Constants
  include Sync::FileToData::Util
  include Authority::FreshdeskRails::ModelHelpers

  attr_accessor :mapping_table, :self_associations, :deleted_associations, :account, :master_account_id, :resync

  DELETE_AGENT_ASSOCIATIONS = {
    'AgentGroup' => ['Group', 'group_id'],
    'UserSkill' =>  ['Admin::Skill', 'skill_id']
  }.freeze
  def initialize(master_account_id, mapping_table, self_associations, deleted_associations, resync = false, account = Account.current)
    @master_account_id = master_account_id
    @mapping_table = mapping_table
    @self_associations = self_associations
    @deleted_associations = deleted_associations
    @resync = resync
    @account = account
    @root_path = "#{GIT_ROOT_PATH}/#{account.id}"
  end

  def perform
    POST_MIGRATION_ACTIVITIES.each do |model, activity|
      activity.call(master_account_id, mapping_table, resync) if mapping_table[model].present?
    end
    clear_account_cache
    update_self_associations
    update_agent_role_permissions
    delete_agent_references
    sync_launch_party_features
  end

  private

    def update_self_associations
      self_associations.uniq.each do |self_association|
        condition = "#{self_association[1]} in (?)"
        condition += " AND #{self_association[2]} = '#{self_association[0]}'" if self_association[2].present?
        self_association[0].constantize.where([condition, mapping_table[self_association[0]][:id].keys]).find_in_batches do |collection|
          collection.each do |obj|
            new_value = mapping_table[self_association[0]][:id][obj.safe_send((self_association[1]).to_s)]
            obj.safe_send("#{self_association[1]}=", new_value)
            obj.save
          end
        end
      end
    end

    def update_agent_role_permissions
      return unless resync
      account.agents.includes(user: :roles).find_in_batches(batch_size: 300) do |agents|
        agents.each do |agent|
          privileges = (union_privileges agent.user.roles).to_s
          privileges = account.roles.agent.first.privileges.to_s if privileges == '0'
          agent.user.update_attribute(:privileges, privileges) if agent.user.privileges != privileges
        end
      end
    end

    def delete_agent_references
      DELETE_AGENT_ASSOCIATIONS.each do |association, reference|
        next if deleted_associations[reference[0]].blank?
        Sync::FileToData::PostMigration::Delete.new({ association.to_s => reference }, deleted_associations).prune_deleted_rows(@root_path, account, 'agents')
        sql = "DELETE from #{model_table_mapping[association]} where #{reference[1]} IN (#{deleted_associations[reference[0]]})"
        ActiveRecord::Base.connection.execute(sql)
      end
    end

    def sync_launch_party_features
      master_account_features = $redis_others.smembers("launchparty:#{master_account_id}:features")
      $redis_others.del("launchparty:#{account.id}:features")
      $redis_others.sadd("launchparty:#{account.id}:features", master_account_features) if master_account_features
    end

    def clear_account_cache
      ACCOUNT_MEMCACHE_KEYS.each do |clear_cache_method|
        account.safe_send(clear_cache_method) if account.respond_to?(clear_cache_method)
      end
    end

    class Sync::FileToData::PostMigration::Delete < Sync::DataToFile::Delete
      def initialize(config, deleted_associations = {})
        super()
        @deleted_associations = deleted_associations
        @config = config
      end

      def delete?(_item, _table_name, object, object_path)
        model_name = object.class.name
        return unless @config.keys.include?(model_name)
        value = YAML.load_file(File.join(object_path, @config[model_name][1] + FILE_EXTENSION))
        @deleted_associations[@config[model_name][0]].include?(value)
      end
    end
end
