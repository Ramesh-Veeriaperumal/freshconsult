class PopulateCompanyFields < ActiveRecord::Migration
  
  shard :all

  def self.up
    Account.find_in_batches(:batch_size => 500) do |accounts|
      accounts.each do |account|
        company_fields = company_fields_data account
        execute(%(
          INSERT INTO company_fields (#{company_fields.first.keys.join(",")}) VALUES 
          #{company_fields.map do |field| "(#{field.values.map{|f| "'#{f}'"}.join(",")})" end.join(",")}
        ))
      end
    end
  end

  def self.down
    execute(%(TRUNCATE TABLE company_fields))
  end

  def self.company_fields_data account
    DEFAULT_FIELDS.each_with_index.map do |f, i|
      {
        :account_id         => account.id,
        :company_form_id    => account.company_form.id,
        :name               => f[:name],
        :column_name        => 'default',
        :label              => f[:label],
        :deleted            => 0,
        :field_type         => CompanyField::DEFAULT_FIELD_PROPS[:"default_#{f[:name]}"][:type],
        :position           => i+1,
        :required_for_agent => f[:required_for_agent] || 0,
        :created_at         => Time.now.to_s(:db),
        :updated_at         => Time.now.to_s(:db)
      }
    end
  end

  DEFAULT_FIELDS =
    [
      { :name               => "name", 
        :label              => "Company Name",
        :required_for_agent => 1 },

      { :name               => "description", 
        :label              => "Description" },
        
      { :name               => "note", 
        :label              => "Notes" },

      { :name               => "domains", 
        :label              => "Domain Names for this company" }
    ]
end