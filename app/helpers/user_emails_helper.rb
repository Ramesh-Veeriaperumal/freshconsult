module UserEmailsHelper
  class FreshdeskDomElement < CustomFields::View::DomElement

    def initialize(form_builder, object_name, class_name, field, field_label, dom_type, required, enabled,
                      field_value = '', dom_placeholder = '', bottom_note = '', args = {})
    @account = args[:account]
    super
    end

    def construct_email
      if @account.features_included?(:contact_merge_ui)
      	construct_user_email
      else
        super
      end
    end

    def construct_disabled
      if @field_name == "email" and @account.features_included?(:contact_merge_ui)
        @field_value = @form_builder.object.user_emails.map(&:email).join(", ")
      end
      super
    end

    private

    def construct_user_email
      output = <<HTML
        <div id="emails_con" class="email_con">
        <ul class="user_emails">
          #{display_user_emails}
        </ul>
        <div class="ue_add_email"><a id="add_new_mail" class="#{@form_builder.object.new_record? ? "disabled" : ""}" href="#">
          <span class="add_pad ue_action_icons ficon-plus fsize-12"></span><span id="add_email"></span>#{t('merge_contacts.add_another')}</a></div>
        </div>
HTML
    output.html_safe
    end

    def display_user_emails
      output = []
      @form_builder.fields_for :user_emails do |ue|
        output << %(<li class="#{ue.object.primary_role ? "disabled" : ""} #{ue.object.new_record? ? "new_email" : ""}">)
        if !ue.object.primary_role
          output << content_tag(:span, "", :class => "remove_pad ue_remove_image ue_action_icons ficon-minus fsize-12", "data-email" => ue.object.id)
          output << ue.text_field(:email, :id => "email_sec_#{ue.object.id}", :class => "email cont text ue_input", "autocomplete" => "off", "data-verified" => ue.object.verified)
          title = t('merge_contacts.make_primary')
        else
          output << %(<span class='remove_pad ue_remove_image ue_action_icons disabled ficon-minus fsize-12'></span>)
          if ue.object.new_record?
            output << ue.text_field(:email, :id => "email_sec", :class => "email cont text ue_input fillone", "autocomplete" => "off", "placeholder" => "Enter an email", "data-verified" => ue.object.verified)
          else
            output << ue.text_field(:email, :id => "email_sec", :class => "email cont disabled text ue_input default_email fillone", "autocomplete" => "off", "disabled" => true, "data-verified" => ue.object.verified)
          end
          title = t('merge_contacts.primary')
        end
        unless ue.object.new_record?
          if ue.object.verified?
            output << content_tag(:span, "", 
                        :class => "email-tick tooltip fsize-20 #{ue.object.primary_role ? "ficon-checkmark-round primary" : "make_primary"}",
                        :title => title)
          else
            output << content_tag(:span, "", :class => "email-tick tooltip ficon-unverified unverified fsize-16", :title => t('merge_contacts.not_verified'))
            output << content_tag(:span, "", 
                        :class => "email-tick tooltip ficon-checkmark-round fsize-20 primary disabled",
                        :title => title) if ue.object.primary_role
          end
        end
        output << ue.hidden_field(:id, :class => "ue_id")
        output << ue.hidden_field(:primary_role, :class => "ue_primary") 
        output << ue.hidden_field(:_destroy, :value => false, :class => "ue_destroy")
        output << %(<label id="email_sec_#{ue.object.id}-error" class="error" for="email_sec_#{ue.object.id}"></label>)
        output << "</li>"
      end
      output.join("").html_safe
    end

  end
end