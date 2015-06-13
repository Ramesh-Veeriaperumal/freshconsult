module CustomFields
  module View

    class DomElement # helper class for creating dom elements, used in contact/_form

      include ActionView::Helpers

      def initialize(form_builder, object_name, class_name, field, field_label, dom_type, required, enabled,
                      field_value = '', dom_placeholder = '', bottom_note = '', args = {})
        @object_name    = "#{object_name.to_s}#{ ( !field.default_field? ) ? '[custom_field]' : '' }"
        @form_builder   = form_builder
        @field          = field
        @dom_type       = dom_type
        @required       = required
        @disabled       = !enabled
        @choices        = field.ui_choices
        @field_value    = field_value.to_s.to_sym
        @field_class    = "#{ (required) ? 'required' : '' } #{dom_type} #{class_name}_#{dom_type}"
        @field_name     = field.name
        @field_label    = CGI.unescapeHTML(field_label)
        @required_star  = "<span class='required_star'>*</span>".html_safe if required
        label           = label_tag "#{object_name}_#{field.field_name}", @field_label
        @label          = content_tag :div, label+@required_star, :class => 'control-label'
        @dom_placeholder= dom_placeholder
        @bottom_note    = content_tag(:div, bottom_note.html_safe, :class => 'info-data')
      end

      def construct
        element = (@disabled and @dom_type != :checkbox) ? construct_disabled : send(:"construct_#{@dom_type}") 
        @dom_type == :checkbox ? wrap_checkbox(element).html_safe : wrap(element).html_safe
      end

      private
        def construct_text
          regex_validity = (@field.field_options and @field.field_options['regex']) ? true : false; 
          maxlength_validity = @field.field_type != :default_domains ? true : false # Temp fix

          html_options = {
                            :class => "#{@field_class}" +
                                (regex_validity ? " regex_validity" : '') +
                                (maxlength_validity ? ' field_maxlength' : ""), 
                            :disabled => @disabled, 
                            :type => 'text'
                          }
          
          html_options['data-regex-pattern'] = "/#{CGI.unescapeHTML(@field.field_options['regex']['pattern'])}/#{@field.field_options['regex']['modifier']}" if regex_validity
          html_options['maxlength'] = '255' if maxlength_validity
          
          text_field_tag("#{@object_name}[#{@field_name}]", @field_value, html_options);
        end

        alias_method :construct_number, :construct_text

        def construct_email
          text_field_tag("#{@object_name}[#{@field_name}]", @field_value, 
                    {:class => @field_class, 
                      :disabled => @disabled, 
                      :type => 'email'})
        end

        def construct_paragraph
          text_area(@object_name, @field_name, 
                    {:class => @field_class, 
                      :value => @field_value, 
                      :disabled => @disabled, 
                      :rows => 5, 
                      :placeholder => @dom_placeholder})
        end
        
        def construct_dropdown_blank
          select(@object_name, @field_name, @choices, 
                                        {:include_blank => "...", :selected => @field_value}, 
                                        {:class => "#{@field_class} input-xlarge select2", 
                                         :disabled => @disabled})
        end

        def construct_dropdown
          select(@object_name, @field_name, @choices, 
                                          {:selected => @field_value},
                                          {:class => "#{@field_class} select2", :disabled => @disabled})
        end

        def construct_checkbox
          checkbox_element = ( @required ? 
            ( check_box_tag(%{#{@object_name}[#{@field_name}]}, 'true', (@field_value == :true), 
                                { :class => @field_class, :disabled => @disabled } )) :
            ( check_box(@object_name, @field_name, {:class => @field_class, 
                                                    :checked => (@field_value == :true), 
                                                    :disabled => @disabled}, true, false) ) )
        end

        def construct_phone_number
          text_field_tag("#{@object_name}[#{@field_name}]", @field_value, 
                    {:class => "#{@field_class} field_maxlength", 
                      :disabled => @disabled,
                      :maxlength => '255'})
        end

        def construct_url
          text_field_tag("#{@object_name}[#{@field_name}]", @field_value, 
                    {:class => "#{@field_class}", 
                      :disabled => @disabled, 
                      :type => 'url'})
        end

        def construct_date
          date_format = format_date
          text_field_tag("#{@object_name}[#{@field_name}]", @field_value, 
                    {:class => "#{@field_class} datepicker_popover", 
                      :disabled => @disabled,
                      :'data-show-image' => "true",
                      :'data-date-format' => AccountConstants::DATA_DATEFORMATS[date_format][:datepicker] })
        end

        def construct_disabled
          anchor ||= begin
            case @dom_type
              when :date
                format_date
                @field_value
              when :url
                content_tag :a, @field_value, :href => @field_value, :target => '_blank'
              when :dropdown_blank
                CGI.unescapeHTML(@field_value.to_s)
              else 
                @field_value
            end
          end
          content_tag :div, anchor, :class => "disabled-field"
        end

        def wrap element
          div = content_tag :div, (element+@bottom_note), :class => 'controls'
          content_tag :li, (@label+div), :class => "control-group #{ @dom_type }"
        end

        def wrap_checkbox element
          @label = label_tag "#{@object_name}_#{@field.field_name}", @field_label
          div    = content_tag(:div, (element + @label + @required_star), :class => 'controls')
          content_tag(:li, div, :class => "control-group #{ @dom_type } #{ @field.field_type } field checkbox-wrap")
        end

        def format_date
          date_format = AccountConstants::DATEFORMATS[Account.current.account_additional_settings.date_format]
          unless @field_value.empty?
            time_format = Account.current.date_type(:short_day_separated)
            @field_value = (Time.parse(@field_value.to_s)).strftime(time_format)
          end 
          date_format
        end

    end

  end
end