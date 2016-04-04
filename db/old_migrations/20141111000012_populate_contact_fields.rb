class PopulateContactFields < ActiveRecord::Migration
  
  shard :all

  def self.up
    Account.find_in_batches(:batch_size => 500) do |accounts|
      accounts.each do |account|
        contact_fields = contact_fields_data account
        execute(%(
          INSERT INTO contact_fields (#{contact_fields.first.keys.join(",")}) VALUES 
          #{contact_fields.map do |field| "(#{field.values.map{|f| "'#{f}'"}.join(",")})" end.join(",")}
        ))
      end
    end
  end

  def self.down
    execute(%(TRUNCATE TABLE contact_fields))
  end

  def self.contact_fields_data account
    DEFAULT_FIELDS.each_with_index.map do |f, i|
      {
        :account_id         => account.id,
        :contact_form_id    => account.contact_form.id,
        :name               => f[:name],
        :column_name        => 'default',
        :label              => f[:label],
        :label_in_portal    => f[:label],
        :deleted            => 0,
        :field_type         => ContactField::DEFAULT_FIELD_PROPS[:"default_#{f[:name]}"][:type],
        :position           => i+1,
        :required_for_agent => f[:required_for_agent] || 0,
        :visible_in_portal  => f[:visible_in_portal]  || 0,
        :editable_in_portal => f[:editable_in_portal] || 0,
        :editable_in_signup => f[:editable_in_signup] || 0,
        :required_in_portal => f[:required_in_portal] || 0,
        :created_at         => Time.now.to_s(:db),
        :updated_at         => Time.now.to_s(:db)
      }
    end
  end

  DEFAULT_FIELDS =
    [
      { :name               => "name", 
        :label              => "Full Name", 
        :required_for_agent => 1,
        :visible_in_portal  => 1, 
        :editable_in_portal => 1,
        :editable_in_signup => 1,
        :required_in_portal => 1 },

      { :name               => "job_title", 
        :label              => "Title", 
        :visible_in_portal  => 1, 
        :editable_in_portal => 1 },
        
      { :name               => "email", 
        :label              => "Email",
        :visible_in_portal  => 1,
        :editable_in_portal => 0,
        :editable_in_signup => 1,
        :required_in_portal => 0 }, # default validations are present in User model(phone || twitter_id || email)

      { :name               => "phone", 
        :label              => "Work Phone", 
        :visible_in_portal  => 1,
        :editable_in_portal => 1 },

      { :name               => "mobile", 
        :label              => "Mobile Phone", 
        :visible_in_portal  => 1, 
        :editable_in_portal => 1 },
        
      { :name               => "twitter_id", 
        :label              => "Twitter", 
        :visible_in_portal  => 1, 
        :editable_in_portal => 1 },

      { :name               => "company_name", 
        :label              => "Company", 
        :visible_in_portal  => 1 },
        
      { :name               => "client_manager", 
        :label              => "Can see all tickets from his company" },

      { :name               => "address", 
        :label              => "Address" },
   
      { :name               => "time_zone", 
        :label              => "Time Zone", 
        :visible_in_portal  => 1, 
        :editable_in_portal => 1 },
      
      { :name               => "language", 
        :label              => "Language", 
        :visible_in_portal  => 1, 
        :editable_in_portal => 1 },

      { :name               => "tag_names", 
        :label              => "Tags" }, 
      
      { :name               => "description", 
        :label              => "Background Information" }
    ]

end