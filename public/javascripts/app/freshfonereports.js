/*jslint browser: true, devel: true */
/*global  App */

window.App = window.App || {};
window.App.Freshfone = window.App.Freshfone || {};
(function ($){
  "user strict";
  App.Freshfonereports = {
    onFirstVisit: function (data) {
      this.onVisit(data);
    },
    onVisit: function (data) {
      this.start();
    },
    onLeave: function (data) {
      this.leave();
    },
    start: function () {
      this.bindHandlers();
    },
    summaryReports: function (url) {
      jQuery('#loading-box').hide();

      $('body').on('click.freshfone_reports',"#submit",function(ev){
        if(jQuery("#report-filter-edit").css('visibility') == 'visible'){
          jQuery('#sliding').click();
        }
        jQuery("#loading-box").show(); 
        jQuery("#freshfone_summary_report .report-page").css('opacity','0.2'); 
        jQuery("#loading-box").css('background','transparent'); 
        jQuery(".reports-loading").css('margin-top','330px'); 
        jQuery.ajax({
            url: url,
            type: "POST",
            data: jQuery('#report_filters').serializeArray(),
            success: function(data){ 
                jQuery("#loading-box").hide(); 
                jQuery("#freshfone_summary_report .report-page").css('opacity','1'); 
                jQuery("#freshfone_summary_report .report-page").removeClass('slide-shadow');
              }
        });

      });
    },
    bindHandlers: function () {
      if(jQuery("#report-filter-edit").css('visibility') == 'visible'){
          jQuery('#sliding').slide();
        }

      $('body').on('click.freshfone_reports','#cancel',function(){
          jQuery('#sliding').click();
      });

      //add the link which fire event on close button.
      $('body').on('click.freshfone_reports', '#filter-close-icon', function(){
          jQuery("#cancel").click();
      });

      $('body').on('click.freshfone_reports', '#export_as_csv', function () {
          $("#generate-pdf").trigger("click");
      });
    },
    groupOptions: function (filter_group_options, placeholder) {
      group_list = JSON.parse(filter_group_options);

      jQuery('#group_id').select2({
          placeholder: placeholder,
          allowClear: true,
          data: {
            text: 'value',
            results:  group_list },
          formatResult: function (result) {
            return result.value;
          },
          formatSelection: function (result) {
            jQuery('#group_id').attr('value',result.id);
            jQuery('#group_id').data('value', result.value);
            return result.value;
          }
        });
    },
    leave: function(){
      $('body').off('.freshfone_reports');
    }
  };

})(jQuery);
