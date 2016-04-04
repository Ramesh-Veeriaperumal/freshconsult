module FormBuilders::Colorpicker

      COLORPICKER_DEFAULTS = {
      }

      def color_picker(options = {})
        color_picker_tag(options).html_safe
      end

      def color_picker_tag(options = {})      
        options = COLORPICKER_DEFAULTS.merge(options)
        output = []
        output << %( <input type='color' id ="#{options[:id]}" class="#{options[:class]}" value="#{options[:value]}" data-hex="true" data-loadedScript="true" name="#{options[:name]}"  maxlength="#{options[:maxlength]}" /> )
        output << %(<script type="text/javascript">
            Fjax.Assets.plugin('colorpicker');
          </script>
        )
        
        output.join(' ').html_safe
      end


end