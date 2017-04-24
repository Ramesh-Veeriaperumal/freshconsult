class AddConfigToOffice365Application < ActiveRecord::Migration
  shard :all

  def migrate(direction)
    self.send(direction)
  end

  def up
    Integrations::Application.find_by_name('office365').update_attributes(
      :options => {
        :direct_install => true,
        :user_specific_auth => true
      }
    )
  end
  
  def down
    Integrations::Application.find_by_name('office365').update_attributes(
      :options => {
        :direct_install => true
      }
    )
  end
end
