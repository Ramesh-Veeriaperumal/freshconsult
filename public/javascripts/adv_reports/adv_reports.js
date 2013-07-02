var Helpkit = Helpkit || { };

var ajaxRepContainer = {};
//all the utils related to reports are defined here.
Helpkit.reports_util = {
  query_hash : $A(),
  select_hash : $A(),
  getFilterDisplayData: function(){
    Helpkit.reports_util.select_hash = $A(); 
    jQuery("li.ff_item,div.ff_item").map(function () {
      var container = this.getAttribute("container");
      var data_label = this.getAttribute("data-label");
      var _selector = 'option:selected'; 
      var value;
      
      if(container == "nested_field") {         
        value = jQuery(this).children('select').val();
      } else {
        value = jQuery(this).find(_selector).map(function(){ return jQuery(this).text(); }).get();
      }

      if((data_label !== null) && value && value.length && value !== '-1' && ((container !== "nested_field") || ((container === "nested_field") && (value !== -1)))){
        Helpkit.reports_util.select_hash.push({ 
          name      : data_label,
          value     : value.toString()
        });
      }
    });
  },
  getFilterData: function(){
    Helpkit.reports_util.query_hash = $A();
    var select_member_hash = $A(); 
    jQuery("li.ff_item,div.ff_item").map(function () {
      condition = this.getAttribute("condition");
      container = this.getAttribute("container");
      operator  = this.getAttribute("operator");
      _selector = 'input:checkbox:checked'; 
      var value;
      if(container == "multi_select" || container == "select"){ _selector = 'option:selected';}

      if(condition == 'responder_id'){
        select_member_hash.push({
          name:jQuery('select[name="Agent"] :selected').text(),
          id:jQuery('select[name="Agent"] :selected').val()
        });
        jQuery("input[name=agent_select_field]").val(select_member_hash.toJSON());
      }
 
      if(condition == 'group_id'){
        select_member_hash.push({
          name:jQuery('select[name="Group"] :selected').text(),
          id:jQuery('select[name="Group"] :selected').val()
        });
        jQuery("input[name=group_select_field]").val(select_member_hash.toJSON());
      }
 
      if(condition == 'customer_id'){
        select_member_hash.push({
          name:jQuery('select[name="Customer"] :selected').text(),
          id:jQuery('select[name="Customer"] :selected').val()
        });
        jQuery("input[name=customer_select_field]").val(select_member_hash.toJSON());
      }

      if(container == "nested_field") {         
        value = jQuery(this).children('select').val();
      } else {
        value = jQuery(this).find(_selector).map(function(){ return this.value; }).get();
      }
                        
      if(value && value.length && ((container != "nested_field") || ((container == "nested_field") && (value != -1)))){
        Helpkit.reports_util.query_hash.push({ 
          condition : this.getAttribute("condition"), 
          operator  : this.getAttribute("operator"),
          value     : value.toString()
        });
      }
    });
  },
  refresh_tickets: function(){
    var _this = Helpkit.reports_util;
    _this.getFilterData();
    _this.getFilterDisplayData();
    jQuery("#FilterOptions input[name=selected_filter_data]").val(_this.select_hash.toJSON()).trigger("change");
    jQuery("#FilterOptions input[name=data_hash]").val(_this.query_hash.toJSON()).trigger("change");
  },
  makeAjaxRequest: function( args ){
    args.type = args.type? args.type: "POST";
    args.url = args.url;
    args.dataType = args.dataType? args.dataType: "json";
    args.data = args.data;
    args.success = args.success? args.success: function(){};
    args.beforeSend = function(){
      if(ajaxRepContainer[args.ajaxType]){
        ajaxRepContainer[args.ajaxType].abort();
      }
    };
    var _request = jQuery.ajax( args );
    if(args.ajaxType){
      ajaxRepContainer[args.ajaxType] = _request;
    }    
  },
  updateReportFilters: function(id){
    Helpkit.reports_util.clearSelect2Filters();
    // added below condition to handle the nested field population.
    var _r_f_data = Helpkit.report_filter_data[id]['data']['data_hash'];
    for(var i =0,_r_f_length = _r_f_data.length; i < _r_f_length; i++){
      var _select_Elm = jQuery("div[condition='"+_r_f_data[i]['condition']+"'] > select");
      _select_Elm.select2('val',_r_f_data[i]['value'].split(','));
      _select_Elm.trigger('change');
    }

    // add reports by filter data if it exists
    if(Helpkit.report_filter_data[id]['data']['reports_by']){
      jQuery("#reports").select2('val',Helpkit.report_filter_data[id]['data']['reports_by']);
      jQuery("#reports").trigger('change')
    }
    //add the comparison fieds 
    if(Helpkit.report_filter_data[id]['data']['comparison_selected']){
      jQuery("#comparison_select").select2('val',Helpkit.report_filter_data[id]['data']['comparison_selected'].split(','));
      jQuery("#comparison_select").trigger('change')
    }
    jQuery("#submit").click();
  },
  clearSelect2Filters: function(){
    jQuery("select[class*='select2']").each(function(){jQuery(this).select2('data',null);})
  },
  saveReportFilter: function(){
    var data = jQuery(".serialize").serializeArray();
    data.push({name : 'filter_name' , value: jQuery("#filter_name").val()});
    data.push({name : 'report_type', value: jQuery("#leftViewMenu").attr("data-report-type")});
    var args ={
      ajaxType: 'report_filter_create',
      type: "POST",
      url: "/reports/report_filter/create",
      dataType: "json",
      data: data,
      success: function(data){
        jQuery("<li/>",{
          'data-id': data['id'],
          'class': 'filter-event',
          text: data['filter_name']
        }).appendTo("#leftViewMenu");

        Helpkit.report_filter_data[data['id']] = {'data': data['data']};
        jQuery("#active_filter").text(data['filter_name']);
        jQuery("#delete-filter-link").removeClass('hide').attr('data-id',data['id']);
        jQuery("#save-filter-link").addClass('hide');
        jQuery("#no-report-data").addClass('hide');
      },
      error: function(data){
        jQuery('#metric_container').html(data.statusText);
        jQuery("#loading-box").addClass('hide');
      }
    };
    Helpkit.reports_util.makeAjaxRequest(args);
  },
  deleteReportFilter: function(id){
    var args ={
      ajaxType: 'report_filter_delete',
      type: "POST",
      url: "/reports/report_filter/destroy/"+id,
      dataType: "json",
      success: function(data){
        jQuery("li[data-id='"+id+"']").remove();
        if(jQuery("#leftViewMenu li").length <= 1){
          jQuery("#no-report-data").removeClass('hide');
        }
      },
      error: function(data){
        jQuery('#metric_container').html(data.statusText);
        jQuery("#loading-box").addClass('hide');
      }
    };
    Helpkit.reports_util.makeAjaxRequest(args);
  },
  bindEventsForReportFilter: function(){
    /** event binds related to saved report starts here**/
    jQuery(document).on('click','.filter-event',function(){
      var _id = jQuery(this).attr('data-id');
      Helpkit.reports_util.updateReportFilters(_id);
      jQuery("#active_filter").text(jQuery(this).text());
      jQuery("#delete-filter-link").removeClass('hide').attr('data-id',_id);
      jQuery("#save-filter-link").addClass('hide');
    });
    jQuery(document).on('click',"#save-filter-link",function(){
      jQuery("#filter_name").val("")
      jQuery("#save-report").click();
    });
    jQuery(document).on('click',"#report-dialog-select-submit",function(){      
      if(jQuery("#filter_name").val() == ""){
        jQuery("#filter-mandatory-check").removeClass('hide');
        return false;
      }
      jQuery("#filter-mandatory-check").addClass('hide');
      Helpkit.reports_util.saveReportFilter();
      jQuery("#report-dialog-select-cancel").click();
    });
    jQuery(document).on('click',"#delete-filter-link",function(){
      Helpkit.reports_util.deleteReportFilter(jQuery(this).attr('data-id'));
      jQuery("#active_filter").text("Unsaved Report");
      jQuery("#save-filter-link").removeClass('hide');
      jQuery("#delete-filter-link").addClass('hide');
    });
    /** event binds related to saved report ends here**/
  },
  set_filter_data: function(){
    filter_obj = eval(jQuery("input[name='selected_filter_data']").val());
    var filter_html = "<li>Filtered by:</li>";
    jQuery.each(filter_obj,function(index,value){
      filter_html += "<li>"+value['name']+" : <strong>"+value['value']+"</strong></li>";
    });
    filter_html += "<li>Time Period : <strong>"+jQuery("#date_range").val()+"</strong></li>";
    jQuery("#filter_container").html(filter_html);
  },
  resizeContainer: function(){
    var _filter_height = jQuery('#report-filter-edit').outerHeight(true);
    var _container_height = jQuery('#report-page').outerHeight(true);
    if((_filter_height) > _container_height)  {
      jQuery('#report-page').height(_filter_height+30);
    }
    else{
      jQuery('#report-page').height(jQuery('#report-page').children().outerHeight(true));
    }
  }
};

//all glance reports related scripts.
Helpkit.GlanceReport = (function(){
   var _FD = {
    _const:{
      'chart_containers':['metric_container','source_container','pie_chart_container','nested_fields_container'],
      'default_charts': ['source','ticket_type','priority'],
      'date_field': 'date_range',
      'filter_container': 'filter_container',
      'reports_for_id_selector': {'agent':'responder_id','helpdesk':'helpdesk','group':'group_id','customer':'customer_id'}
    },
    bindEvents: function(){
      jQuery("#submit").on('click',function(){
        jQuery("#loading-box").removeClass('hide');
        _FD.flush_containers();
        if(jQuery("#report-filter-edit").css('visibility') == 'visible'){
          jQuery('#sliding').click();
        }
        jQuery("#report_header_date").text(jQuery("#"+_FD._const['date_field']).val());
        _FD.set_filter_data();
        _FD.populate_metric();
        _FD.populate_charts();
      });

      jQuery("#dialog-select-submit").live('click',function(event){
        if(jQuery("#select_saved_report").val()){
          jQuery("#leftViewMenu > li[data-id='"+jQuery("#select_saved_report").val()+"']").click();
          jQuery("#dialog-select").modal("hide");
          return;
        }
        if(jQuery("#select_option_div").val() === null || jQuery("#select_option_div").val() === ""){
          jQuery("#mandatory-check").removeClass("hide");
          event.stopPropagation();
          return;
        }
        var value = jQuery("#select_option_div").val();
        var _this =Helpkit.reports_util;
        jQuery("#"+_FD._const['reports_for_id_selector'][_FD.report_type]).select2('val',jQuery('#select_option_div').val());
        _this.getFilterData();
        _this.getFilterDisplayData();
        jQuery("#FilterOptions input[name=selected_filter_data]").val(_this.select_hash.toJSON()).trigger("change");
        jQuery("#FilterOptions input[name=data_hash]").val(_this.query_hash.toJSON()).trigger("change");
        jQuery("#loading-box").removeClass('hide');
        jQuery("#submit").click();
        jQuery("#dialog-select").modal("hide");
      });

    },
    set_filter_data: function(){
      _FD.set_report_title();
      Helpkit.reports_util.set_filter_data();
    },
    flush_containers: function(){
      jQuery.each(_FD._const['chart_containers'], function(index, value) {
        jQuery('#'+value).html("");
      });
    },
    set_report_title: function(){
      title = jQuery("#"+_FD._const['reports_for_id_selector'][_FD.report_type]+" :selected").text();
      if (title === ""){
        jQuery("#report_header_title").text( _FD.report_title );
      }
      else{
        jQuery("#report_header_title").text( _FD.report_title +" - "+title);
      }
    },
    populate_metric: function(){
      data = jQuery(".serialize").serializeArray();
      var args ={
        ajaxType: 'fetch_metrics',
        type: "POST",
        url: _FD._url+"/fetch_metrics",
        dataType: "html",
        data: data,
        success: function(data){
          jQuery('#metric_container').append(data);
          jQuery("#report-page").height('auto');
          jQuery("#loading-box").addClass('hide');
          jQuery("#sla_gauge_container .highcharts-container,#fcr_gauge_container .highcharts-container").css({ left: '-30px' });
        },
        error: function(data){
          if(data.statusText != 'abort'){
            jQuery('#metric_container').html(data.statusText);
          }
          jQuery("#loading-box").addClass('hide');
        }
      };
      Helpkit.reports_util.makeAjaxRequest(args);
    },
    populate_charts: function(){
      jQuery.each(_FD._const['default_charts'], function(index, value) {
        _FD.fetch_chart_data(value);
      });
      if(jQuery("#reports").val()){
        jQuery.each(jQuery("#reports").val(), function(index, value) {
          _FD.fetch_chart_data(value);
        });
      }
    },
    fetch_chart_data: function(val){
      data = jQuery(".serialize").serializeArray();
      data.push({'name':'reports_by','value':val});
      var args ={
        ajaxType: val,
        type: "POST",
        url: _FD._url+"/fetch_activity_ajax",
        dataType: "html",
        data: data,
        success: function(data){
          var chart_id = jQuery(jQuery(data)[0]).attr('data-chart-id');
          jQuery('#'+chart_id).append(data);
          jQuery("#report-page").height('auto');
        },
        error: function(data){
          if(data.statusText != 'error' && data.statusText != 'abort')
            jQuery("#noticeajax").text(data.statusText).show();
        }
      };
      Helpkit.reports_util.makeAjaxRequest(args);
    }
   };

   return {
      init: function(opts){
        _FD.report_type = opts['report_type'];
        _FD._url = opts['_url'];
        _FD.report_title = opts['title'];
        if(_FD.report_type === 'helpdesk'){
          jQuery("#loading-box").removeClass('hide');
        }
        else{
          jQuery("#loading-box").addClass('hide');
        }

        jQuery('#sliding').slide();
        _FD.bindEvents();
        _FD.set_filter_data();
        if(_FD.report_type === 'helpdesk'){
          _FD.flush_containers();
          _FD.populate_metric();
          _FD.populate_charts();
        }
        else{
          jQuery('#select-opt').click();
        }
        jQuery("#report_header_date").text(opts['date_range']);
      }
   };
    
})();

//all analysis reports related scripts are below..
Helpkit.AnalysisReport = (function(){
   var _FD = {
    _const:{
      'agent_group_containers':['resolved_tickets','backlog_tickets','SLA_DESC_tickets','SLA_ASC_tickets',
                          'FCR_tickets'],
      'customer_chart_containers':['resolved_tickets','backlog_tickets','received_tickets',
                                   'SLA_tickets','happy_customers','frustrated_customers'],
      'date_field': 'date_range',
      'filter_container': 'filter_container'
    },
    get_container: function(){
      var type = _FD.report_type;
      return type === 'customer' ? _FD._const['customer_chart_containers'] : _FD._const['agent_group_containers'];
    },
    bindEvents: function(){
      jQuery("#submit").on('click',function(){
        jQuery("#loading-box").removeClass('hide');
        _FD.flush_containers();
        if(jQuery("#report-filter-edit").css('visibility') == 'visible'){
          jQuery('#sliding').click();
        }
        jQuery("#report_header_date").text(jQuery("#"+_FD._const['date_field']).val());
        _FD.set_filter_data();
        _FD.populate_charts();
      });
    },
    set_filter_data: function(){
      Helpkit.reports_util.set_filter_data();
    },
    flush_containers: function(type){
      jQuery.each(_FD.get_container(), function(index, value) {
        jQuery('#'+value+"_line_chart").html("");
      });
    },
    populate_charts: function(){
      jQuery.each(_FD.get_container(), function(index, value) {
        _FD.fetch_chart_data(value);
      });
    },
    fetch_chart_data: function(val){
      data = jQuery(".serialize").serializeArray();
      data.push({'name':'reports_by','value':val});
      var args ={
        ajaxType: val,
        type: "POST",
        url: _FD._url,
        dataType: "json",
        data: data,
        success: function(data){
          var chart_id = val+'_line_chart';
          var analysis_1_barChart = new bar_chart(
              {renderTo: chart_id,chartData:data[val]['chartData'],
                xaxis_arr: data[val]['xaxis_arr'],title:'',
                yAxis_label:data[val]['yAxisLabel']
              });
          analysis_1_barChart.barGraph();
          jQuery("#"+chart_id).removeClass('sloading loading-small loading-block');
          jQuery("#loading-box").addClass('hide');
          jQuery("#report-page").height('auto');
        },
        error: function(data){
          var chart_id = val+'_line_chart';
          if(data.statusText != 'abort'){
            jQuery("#"+chart_id).text(data.statusText);
          }          
          jQuery("#"+chart_id).removeClass('sloading loading-small loading-block');
        }
      };
      Helpkit.reports_util.makeAjaxRequest(args);
    }
   };

   return {
      init: function(opts){
        _FD.report_type = opts['report_type'];
        _FD._url = opts['_url'];
        jQuery("#loading-box").removeClass('hide');
        jQuery('#sliding').slide();
        _FD.bindEvents();
        _FD.set_filter_data();
        _FD.populate_charts();
        jQuery("#report_header_title").text(opts['title']);
        jQuery("#report_header_date").text(opts['date_range']);
      }
   };
    
})();

//all comparison related reports are below.
Helpkit.ComparisonReport = (function(){
   var _FD = {
    _const:{
      'date_field': 'date_range',
      'filter_container': 'filter_container',
      'report_home_url': '/reports',
      'agent_max_alert': 'You can select a maximum of 4 agents.',
      'group_max_alert': 'You can select a maximum of 4 groups.',
      'agent_mand_alert': 'Agent and Metrics are required to generate report.',
      'group_mand_alert': 'Group and Metrics are required to generate report.'
    },
    validateSelectedComparison: function(members_select_id,comparison_select_id,error_id){
      if(jQuery("#"+members_select_id).length === 1 && jQuery("#"+comparison_select_id).length === 1){
        if(jQuery("#"+members_select_id).val() === null || jQuery("#"+comparison_select_id).val() === null){
          jQuery("#"+error_id).text(_FD._const[_FD.report_type+"_mand_alert"]).show();
          return false;
        }
        else if(jQuery("#"+members_select_id).val().length > 4){
          jQuery("#"+error_id).text(_FD._const[_FD.report_type+"_max_alert"]).show();
          return false;
        }
      }
      jQuery("#"+error_id).hide();
      return true;
    },
    bindEvents: function(){
      jQuery('#members_select,#comparison_select').bind('change',function(event){
        jQuery('input[name='+jQuery(this).attr("id")+'ed]').val(jQuery(this).val());
      });

      jQuery("#submit").click(function(){
        if(_FD.validateSelectedComparison("members_select","comparison_select","noticeajax")){
          if(jQuery("#report-filter-edit").css('visibility') == 'visible'){
            jQuery('#sliding').click();
          }
          jQuery("#loading-box").removeClass('hide');
          _FD.populate_charts();
        }
      });

      jQuery("#dialog-select-submit").live('click',function(event){
        if(jQuery("#select_saved_report").val()){
          jQuery("#leftViewMenu > li[data-id='"+jQuery("#select_saved_report").val()+"']").click();
          jQuery("#dialog-select").modal("hide");
          return;
        }
        if(!_FD.validateSelectedComparison("agent_select_option","metric_select_option","mandatory-check")){
          event.stopPropagation();
          return;
        }
        jQuery('#members_select').select2('val',jQuery('#agent_select_option').val());
        jQuery("#members_select").trigger('change');
        jQuery('#comparison_select').select2('val',jQuery('#metric_select_option').val());
        jQuery("#comparison_select").trigger('change');
        Helpkit.reports_util.getFilterData();
        Helpkit.reports_util.getFilterDisplayData();
        jQuery("#FilterOptions input[name=selected_filter_data]").val(Helpkit.reports_util.select_hash.toJSON()).trigger("change");
        jQuery("#FilterOptions input[name=data_hash]").val(Helpkit.reports_util.query_hash.toJSON()).trigger("change");
        jQuery("#loading-box").removeClass('hide');
        jQuery("#submit").click();
        jQuery("#dialog-select").modal("hide");
      });

      jQuery('#dialog-select-cancel').live('click',function(event){
        window.location.replace('/reports');
        event.stopPropagation();
      });
    },
    set_filter_data: function(){
      Helpkit.reports_util.set_filter_data();
    },
    create_hidden_ele: function(){
      jQuery("<input/>", {
        name: 'comparison_selected',
        type: 'hidden'
      }).addClass('serialize').appendTo("#FilterOptions");
      
      jQuery("<input/>", {
        name: 'members_selected',
        type: 'hidden'
      }).addClass('serialize').appendTo("#FilterOptions");
    },
    populate_charts: function(){
      data = jQuery(".serialize").serializeArray();
      var args ={
        ajaxType: 'comparision_report',
        type: "POST",
        url: _FD._url+"/generate",
        dataType: "html",
        data: data,
        success: function(data){
          jQuery('#ticket-list-body-content').html(data);
          _FD.set_filter_data();
          jQuery("#loading-box").addClass('hide');
          //need to check for better approach 
          // The var _slide_init is defined in each comparision report index page
          if(_slide_init == false){
            jQuery('#sliding').slide();
            _slide_init = true;
          }
        },
        error: function(data){
          if(data.statusText != 'abort'){
            jQuery('#ticket-list-body-content').text(data.statusText);
            jQuery("#loading-box").removeClass('hide');
          }
        }
      };
      Helpkit.reports_util.makeAjaxRequest(args);
    }
   };

   return {
      init: function(opts){
        _FD.report_type = opts['report_type'];
        _FD._url = opts['_url'];
        _FD.create_hidden_ele();
        _FD.bindEvents();
        jQuery('#agent_select_option').select2({maximumSelectionSize:4});
        jQuery('#select-opt').trigger("click");
        Helpkit.reports_util.set_filter_data();
      }
   };  
})();