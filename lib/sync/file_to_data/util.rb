module Sync::FileToData::Util
  def self.included(base)
    [Sync::CustomLogger, Sync::Util, Sync::Constants, Sync::Transformer::Util, Sync::SqlUtil].each do |file|
      base.send(:include, file)
    end
  end

  def model_table_mapping
    @model_table_mapping ||= Hash[ActiveRecord::Base.safe_send(:descendants).collect { |c| [c.name, c.table_name] }]
  end

end
