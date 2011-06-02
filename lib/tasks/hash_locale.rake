namespace :i18n do
  desc 'Add some random strings around values in en.yml'
  task :rumble => :environment do
    puts "I18n Test..."
    
    f_name = "#{RAILS_ROOT}/config/locales/en.yml"
    en_content = File.open(f_name, 'r') { |f| f.read }
    en_data = YAML.load(en_content)

    n_data = add_hash_to_val(en_data)
    File.open(f_name, 'w+') { |f| f.write YAML.dump(n_data) }
  end
end

def add_hash_to_val(obj)
  if obj.is_a?(Hash)
    returning(Hash.new) do |map|
      obj.each { |k,v| map[k] = add_hash_to_val(v) }
    end
  elsif obj.is_a?(Array)
    array = Array.new
    obj.each_with_index { |v,i| array[i] = add_hash_to_val(v) }
    return array
  else
    return "@@#{obj}@@"
  end
end
