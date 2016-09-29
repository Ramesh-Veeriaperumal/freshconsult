/*
	Module deals with events associated with surveys list.
*/
var SurveyList = {
      change: function(obj){
      		SurveyUtil.updateState();
      		SurveyTab.resetState();
            var surveyId = jQuery(obj).val();
      		SurveyState.filterChanged = true;
            SurveyState.fetch();

      },

      bind: function(){
        jQuery(document).ready(function(){
          jQuery('.deleted_list').attr('disabled','disabled');
          jQuery('#survey_main_layout').append(JST["survey/reports/template/main_content"]({
            agentReporting: SurveyReport.agentReporting
          }));
          jQuery('#survey_main_layout').on('click.survey_reports', function(){
            jQuery('#reports_type_menu').hide();
          })
          jQuery("#export_csv").on('click.helpdesk_reports',function(){
            var _url = jQuery(this).data('exportUrl');
            params = SurveyList.getExportParams();
            jQuery.ajax({
              url: _url,
              contentType: 'application/json',
              type: "POST",
              data: Browser.stringify(params),
              success: function(data){ 
                   var text = "<span id='email_reports_msg'>"+I18n.t('adv_reports.report_export_success')+"</span>";
                   SurveyList.showResponseMessage(text);     
                }
            })
          })
        })
      },

      showResponseMessage:function(message) {
        jQuery("#email-reports-msg").remove();
        var msg_dom = jQuery("#noticeajax");
        msg_dom.empty();
        msg_dom.prepend(message);
        msg_dom.show();
        jQuery("<a />").addClass("close").attr("href", "#").appendTo(msg_dom).on('click.helpdesk_reports', function(){
            msg_dom.fadeOut(600);
            return false;
        });
        setTimeout(function() {    
            jQuery("#noticeajax a").trigger( "click" );  
            msg_dom.find("a").remove();
        }, 1200);
            
      },

      getExportParams:function() {
        var params = {};
        var form_data = [];
        params.data_hash = {};
        var filterName;

        var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));

        if(current_selected_index == -1) {
          filterName = jQuery("#report-title").text().trim();
        }
        else {
          filterName = Helpkit.report_filter_data[current_selected_index].report_filter.filter_name;
        }

        var surveyObj  = jQuery("#survey_report_survey_list");
        var groupObj   = jQuery("#survey_report_group_list");
        var agentObj   = jQuery("#survey_report_agent_list");
        var dateObj    = jQuery("#survey_date_range");

        params.data_hash = {};

        params.data_hash.date = {};
        params.data_hash.date.date_range = dateObj.val();
        params.data_hash.select_hash     = SurveyList.getFilterText();
        params.data_hash.survey_id       = surveyObj.val();
        params.data_hash.group_id        = groupObj.val();
        params.data_hash.agent_id        = agentObj.val();
        params.data_hash.filter_name     = filterName;

        return params;
      },

      getFilterText:function() {
        var filters_name = ["survey_report_survey_list", "survey_report_group_list" ,"survey_report_agent_list"];
        var labels = [
          I18n.t('reports.survey_reports.main.survey_name'),
          I18n.t('reports.survey_reports.main.group'),
          I18n.t('reports.survey_reports.main.agent') 
        ]; 

        var display = [];
        jQuery.each(filters_name,function(idx,name){
          var selected_options = [];
          selected_options = jQuery('#' + name + ' option:selected');
          var txt = selected_options.text();
          var data = {
            name : labels[idx],
            value : txt
          }
          display.push(data);
        });
        return display;
      }
}