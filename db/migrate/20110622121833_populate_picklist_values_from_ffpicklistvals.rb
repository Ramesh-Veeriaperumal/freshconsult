class PopulatePicklistValuesFromFfpicklistvals < ActiveRecord::Migration
  def self.up
    FlexifieldPicklistVal.all.each do |ff_pval|
      ff_pval.flexifield_def_entry.ticket_field.picklist_values.create!(
        :value => ff_pval.value.blank? ? 'None' : ff_pval.value )
    end
  end

  def self.down
  end
end
