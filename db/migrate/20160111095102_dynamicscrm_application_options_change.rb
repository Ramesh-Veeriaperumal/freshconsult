class DynamicscrmApplicationOptionsChange < ActiveRecord::Migration
  shard :all

  def up
    app = Integrations::Application.find_by_name("dynamicscrm")
    if app.present?
      app.options = { :direct_install => true,
                      :auth_url => "/integrations/dynamicscrm/settings",
                      :edit_url => "/integrations/dynamicscrm/edit",
                      :default_fields => {:contact => ["Telephone"], :account => ["Telephone"], :lead => ["Telephone"]}
                    }
      app.save!
    end
  end

  def down
    app = Integrations::Application.find_by_name("dynamicscrm")
    if app.present?
      app.options = { :direct_install => true,
                      :auth_url => "dynamicscrm/settings",
                      :edit_url => "dynamicscrm/edit",
                      :default_fields => {:contact => ["Telephone"], :account => ["Telephone"], :lead => ["Telephone"]}
                    }
      app.save!
    end
  end
end
