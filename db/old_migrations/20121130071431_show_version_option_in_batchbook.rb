class ShowVersionOptionInBatchbook < ActiveRecord::Migration

@app_name = "batchbook"
@widget_name = "batchbook_widget"

  def self.up
    app = Integrations::Application.find_by_name('batchbook')
    app.options[:version].delete(:css_class)
    app.options[:version][:default_value] = "auto"
    app.options[:version][:choices] = [ 
                                        ["integrations.batchbook.form.version.auto_detect", "auto"],
                                        ["integrations.batchbook.form.version.new", "new"],
                                        ["integrations.batchbook.form.version.classic", "classic"]
                                      ]
    app.options[:before_save] = {
                                    :method => 'detect_batchbook_version',
                                    :clazz => 'Integrations::BatchbookVersionDetector'
                                }
    app.save!
    wid = app.widgets.first
    wid.script = %(      
      <div id="batchbook_widget"  class="integration_widget crm_contact_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        jQuery(document).ready(function(){
          batchbookBundle={ domain:"{{batchbook.domain}}", k:"{{batchbook.api_key}}", reqEmail: "{{requester.email}}", reqName: "{{requester.name}}", ver: "{{batchbook.version}}"};
          CustomWidget.include_js("/javascripts/integrations/batchbook.js");
        });
      </script>
      )
    wid.save!
  end

  def self.down
    app = Integrations::Application.find_by_name('batchbook')
    app.options[:version][:choices] = ["integrations.batchbook.form.version.classic", "integrations.batchbook.form.version.new"]
    app.options[:version][:default_value] = "integrations.batchbook.form.version.classic"
    app.options[:version].merge!({:css_class => "hide"})
    app.options.delete(:before_save)

    app.save!
    wid = app.widgets.first
    wid.script = %(      
      <div id="batchbook_widget"  class="integration_widget crm_contact_widget">
        <div class="content"></div>
      </div>
      <script type="text/javascript">
        jQuery(document).ready(function(){
          batchbookBundle={ domain:"{{batchbook.domain}}", k:"{{batchbook.api_key}}", reqEmail: "{{requester.email}}", reqName: "{{requester.name}}"};
          CustomWidget.include_js("/javascripts/integrations/batchbook.js");
        });
      </script>
      )
    wid.save!
  end
end
