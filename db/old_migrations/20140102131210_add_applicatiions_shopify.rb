class AddApplicatiionsShopify < ActiveRecord::Migration
  shard :all
  def self.up
    shopify = Integrations::Application.create(
        :name => "shopify",
        :display_name => "integrations.shopify.label",
        :description => "integrations.shopify.desc",
        :listing_order => 24,
        :options => {:direct_install => false, :keys_order => [:shop_name],
                     :shop_name => { :type => :text, :required => true, :label => "integrations.shopify.form.shop_name", :info => "integrations.shopify.form.shop_name_info", :rel => "ghostwriter", :autofill_text => ".myshopify.com"},
        },
        :application_type => "shopify",
        :account_id => Integrations::Constants::SYSTEM_ACCOUNT_ID )
    shopify.save
  end

  def self.down
    Integrations::Application.find(:first, :conditions => {:name => "shopify"}).delete
  end


end
