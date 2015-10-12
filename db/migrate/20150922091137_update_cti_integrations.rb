class UpdateCtiIntegrations < ActiveRecord::Migration
  shard :all
  def up
    app1 = Integrations::Application.find_by_name("drishti")
    app1.options[:dimensions] = {:width => "200px",:height => "450px"}
    app1.options[:keys_order] = [:host_ip, :convert_to_ticket, :add_note_as_private]
    app1.options[:add_note_as_private] = {:type => :checkbox, :label => "integrations.cti.add_note_as_private", :default_value => '1'}
    app1.options[:after_commit] = {:clazz => 'Integrations::Cti',:method => 'clear_memcache'}
    app1.save

    app2 = Integrations::Application.find_by_name("five9")
    app2.options = {}
    app2.options[:direct_install] = false
    app2.options[:dimensions] = {:width => "200px",:height => "450px"}
    app2.options[:keys_order] = [:convert_to_ticket, :add_note_as_private]
    app2.options[:add_note_as_private] = {:type => :checkbox, :label => "integrations.cti.add_note_as_private", :default_value => '1'}
    app2.options[:convert_to_ticket] = {:type => :checkbox, :label => "integrations.cti.convert_to_ticket", :default_value => '1'}
    app2.options[:after_commit] = {:clazz => 'Integrations::Cti',:method => 'clear_memcache'}
    app2.save

    app3 = Integrations::Application.find_by_name("czentrix")
    app3.options[:dimensions] = {:width => "250px",:height => "350px"}
    app3.options[:keys_order] = [:host_ip, :convert_to_ticket, :add_note_as_private]
    app3.options[:add_note_as_private] = {:type => :checkbox, :label => "integrations.cti.add_note_as_private", :default_value => '1'}
    app3.options[:after_commit] = {:clazz => 'Integrations::Cti',:method => 'clear_memcache'}
    app3.save

  end

  def down
    app1 = Integrations::Application.find_by_name("drishti")
    app1.options.delete(:dimensions)
    app1.options.delete(:after_commit)
    app1.options.delete(:add_note_as_private)
    app1.options[:keys_order] = [:host_ip, :convert_to_ticket]
    app1.save

    app2 = Integrations::Application.find_by_name("five9")
    app2.options = {}
    app2.options[:direct_install] = true
    app2.save

    app3 = Integrations::Application.find_by_name("czentrix")
    app3.options.delete(:dimensions)
    app3.options.delete(:after_commit)
    app3.options.delete(:add_note_as_private)
    app3.options[:keys_order] = [:host_ip, :convert_to_ticket]
    app3.save

  end

end
