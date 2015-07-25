class HelpdeskReports::Response::Ticket::Base

  include HelpdeskReports::Constants::Ticket
  include HelpdeskReports::Util::Ticket

  attr_accessor :raw_result, :processed_result, :date_range

  def initialize result, date_range
    @raw_result       = result
    @date_range       = date_range
    @processed_result = {}    
  end

  def process
    process_metric if raw_result.present? # return empty hash if ZERO sql rows
    map_field_ids_to_values
    map_flexifield_to_label
    processed_result
  end

  private

  def map_flexifield_to_label
    processed_result.keys.each do |column_name|
      next unless column_name.to_s.starts_with?("ffs")
      label = flexifield_label_from_db(column_name)
      processed_result[label] = processed_result[column_name]
      processed_result.delete(column_name)
    end
  end

  def flexifield_label_from_db column_name
    def_entry = Account.current.flexifield_def_entries.where(:flexifield_name => column_name).first
    def_entry ? def_entry.ticket_field.label.to_sym : ""
  end

  def map_field_ids_to_values
    processed_result.each do |column_name, value|
      if reverse_mapping_required?(column_name)
        mapping_hash = field_id_to_name_mapping(column_name)
        convert_id_to_names(value, mapping_hash)
        #merge_empty_fields_with_zero(value,mapping_hash)
      end
    end
  end

  # If we have result for an option (say custom ticket_type, status) which is been deleted now
  # it is shown as NA in report result (to match with metric result)
  # All such values are added in single NA for Count metrics.
  # For Avg and Percentage metrics, these cannot be simply added (illegal maths), hence
  # these values are shown as NA-1, NA-2 .. likewise, if there exists multiple such entries.
  def convert_id_to_names(value, mapping_hash)
    na_count = 1
    value.keys.each do |k|
      if self.class == HelpdeskReports::Response::Ticket::Count
        new_key = mapping_hash[k.to_i] || NOT_APPICABLE
        value[new_key] = value[new_key].to_i + value[k] #incase we have multiple NA values
      else
        if mapping_hash[k.to_i]
          new_key = mapping_hash[k.to_i]
        else
          new_key = na_count == 1 ? NOT_APPICABLE : "#{NOT_APPICABLE}-#{na_count}"
          na_count += 1
        end
        value[new_key] = value[k]
      end
      value.delete(k)
    end
  end

  def merge_empty_fields_with_zero(value,mapping_hash)
    mapping_hash.keys.each do |k|
      value[mapping_hash[k]] ||= 0
    end
  end

  def calculate_difference_percentage previous_val, current_val
    return NOT_APPICABLE if previous_val == 0 || [previous_val, current_val].include?(NOT_APPICABLE)
    precentage = (current_val - previous_val)*100/ previous_val.to_f
    precentage.round(2)
  end
    
  def benchmark_query?
    !raw_result.blank? and !raw_result.first.blank? and !raw_result.first[COLUMN_MAP[:benchmark]].blank?
  end
  
  def explain 
    puts JSON.pretty_generate @processed_result
  end

  def sort_keys
    # TODO
  end  

end
