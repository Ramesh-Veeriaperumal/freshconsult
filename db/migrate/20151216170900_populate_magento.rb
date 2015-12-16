class PopulateMagento < ActiveRecord::Migration
  shard :all
  def up
    magento = Integrations::Application.create(
        :name => "magento",
        :display_name => "integrations.magento.label",
        :description => "integrations.magento.desc",
        :listing_order => 38,
        :options => {:direct_install => true,
                 :auth_url => "/magento/new",
                 :edit_url => "/magento/edit"
                },
        :application_type => "magento",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
  end

  def down
    Integrations::Application.find_by_name("magento").destroy
  end
end
