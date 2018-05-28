class AddThresholdApiConfigToHelpdeskReportsConfig < ActiveRecord::Migration
  shard :none
  def self.up

    execute <<-SQL
    INSERT INTO helpdesk_reports_config (id, name, config_json)
    VALUES
    (1, 'Threshold Api', '{\"days_limit\":30,\"request_bacth_size\":2,\"warning_pc\":{\"count\":10,\"avg\":10,\"percentage\":2.5},\"danger_pc\":{\"count\":20,\"avg\":20,\"percentage\":5}}');
    SQL
  end
end
