module Integrations::IntegrationHelper

  def construct_rules(data, default_value)
    unless data.empty?
      output = ""
      output << %(<div class='rules_wrapper construct_rules' id='construct_rules' rel='construct_rules' data-default-value='#{default_value.html_safe}'>)

      data.each do |value|
        
        if ( value[:type] == 'dropdown' )
          channel = value[:options]
          output << select_tag(value[:name], options_for_select(channel.collect{ |c| [c["name"],c["id"]]}), 
            { :class => "drop_first " , :rel => "dropdown", "data-refer-key" => value[:refer_key]})
        elsif (value[:type] == 'multi_select')

          output << select_tag(value[:name], options_for_select(value[:options]), { :class => "drop_second" , :rel => "multi_select", "data-refer-key" => value[:refer_key]})
        elsif (value[:type] == 'input_text')

          output << %(<input type="text" name="#{value[:name]}" class="input_text" rel="input_text" data-refer-key="#{value[:refer_key]}" >)
        end

      end

      output << %(</div>)
      output.html_safe
    end
  end

end