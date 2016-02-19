
jQuery(document).ready(function() {

    jQuery("#exportLink").click(function(){
            var opts = {
                    url : '/timesheet_reports/configure_export',
                    type: 'GET',
                    dataType: 'json',
                    contentType: 'application/json',
                    success: function (data) {
                      var tmpl = JST["helpdesk_reports/templates/export_fields_tmpl"]({
                            'data': data
                        });
                        jQuery("#ticket_fields").removeClass('sloading loading-small');
                        jQuery('#ticket_fields').html(tmpl);
                        bindExportFieldEvents();
                    },
                    error: function (data) {
                        _this.appendExportError();
                    }
                };
                jQuery.ajax(opts);
    });

    function bindExportFieldEvents() {

        var export_fields = jQuery("#ticket_fields input[type='checkbox']");
        jQuery('#toggle_checks').on('change', function () {
                jQuery(export_fields).prop('checked', jQuery(this).is(":checked"));
        });

        //For toggling select all/none checkbox when toggling fields -->
        jQuery(export_fields).on('change', function () {
            var count = 0;
            jQuery(export_fields).each(function(i,ele){ if(ele.checked) count++; });
            jQuery('#toggle_checks').prop('checked', (jQuery(export_fields).length == count));
        });

        jQuery("#export_submit").click(function () {  
            if (jQuery('#ticket_fields :checked').length == 0) {
                jQuery('#err_no_fields_selected').removeClass('hide');
                return false;
            } else {
                jQuery('#err_no_fields_selected').addClass('hide');
                jQuery("#export_submit").prop('disabled', 'disabled').addClass("disabled").html("Exporting...");
            }
        });
    }
});

//Analytics
    
function recordAnalytics(){

    jQuery(document).on("script_loaded", function (ev, data) {
         App.Report.Metrics.push_event("TimeSheet Report Visited", {});
    });
    //Download link
    jQuery(".proxy-generate-pdf").click(function(ev) {
        App.Report.Metrics.push_event("TimeSheet PDF Downloaded", {});
    });
    jQuery("#export_as_csv").click(function(ev) {
        App.Report.Metrics.push_event("TimeSheet CSV Exported", {});
    });
    jQuery("#submit").click(function(ev) {
        App.Report.Metrics.push_event("TimeSheet Report Generated", {
            Date: jQuery("#date_range").val()
        });
    });
}

