class CreateMobileAppVersions < ActiveRecord::Migration
  shard :shard_1
  def change
    create_table :mobile_app_versions do |t|
    	t.integer :mobile_type
      	t.string :app_version
      	t.boolean :supported
      	t.timestamps
    end
  end
end
