var Helpkit = Helpkit || { };

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
    jQuery.ajax( args );
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
      'reports_for_id_selector': {'agent':'Agent','helpdesk':'helpdesk','group':'Group','customer':'Customer'}
		},
    bindEvents: function(){
      jQuery("#submit").on('click',function(){
        jQuery("#loading-box").removeClass('hide');
        _FD.flush_containers();
        jQuery('#sliding').click();
        jQuery("#report_header_date").text(jQuery("#"+_FD._const['date_field']).val());
        _FD.set_filter_data();
        _FD.populate_metric();
        _FD.populate_charts();
      });

      jQuery("#dialog-select-submit").live('click',function(event){
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
        jQuery('#sliding').click();
        jQuery("#submit").click();
        jQuery("#dialog-select").modal("hide");
      });

    },
    set_filter_data: function(){
      _FD.set_report_title();
      filter_obj = eval(jQuery("input[name='selected_filter_data']").val());
      var filter_html = "<li>Filtered by:</li>";
      jQuery.each(filter_obj,function(index,value){
        filter_html += "<li>"+value['name']+" : <strong>"+value['value']+"</strong></li>";
      });
      filter_html += "<li>Time Period : <strong>"+jQuery("#"+_FD._const['date_field']).val()+"</strong></li>";
      jQuery("#"+_FD._const['filter_container']).html(filter_html);
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
          jQuery('#metric_container').html(data.statusText);
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
          if(data.statusText != 'error')
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
        jQuery('#sliding').click();
        jQuery("#report_header_date").text(jQuery("#"+_FD._const['date_field']).val());
        _FD.set_filter_data();
        _FD.populate_charts();
      });
    },
    set_filter_data: function(){
      filter_obj = eval(jQuery("input[name='selected_filter_data']").val());
      var filter_html = "<li>Filtered by:</li>";
      jQuery.each(filter_obj,function(index,value){
        filter_html += "<li>"+value['name']+" : <strong>"+value['value']+"</strong></li>";
      });
      filter_html += "<li>Time Period : <strong>"+jQuery("#"+_FD._const['date_field']).val()+"</strong></li>";
      jQuery("#"+_FD._const['filter_container']).html(filter_html);
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
          jQuery("#"+chart_id).removeClass('loading-box');
          jQuery("#loading-box").addClass('hide');
          jQuery("#report-page").height('auto');
        },
        error: function(data){
          var chart_id = val+'_line_chart';
          jQuery("#"+chart_id).text(data.statusText);
          jQuery("#"+chart_id).removeClass('loading-box');
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
      'report_home_url': '/reports'
    },
    validateSelectedComparison: function(members_select_id,comparison_select_id,error_id){
      if(jQuery("#"+members_select_id).length === 1 && jQuery("#"+comparison_select_id).length === 1){
        if(jQuery("#"+members_select_id).val() === null || jQuery("#"+comparison_select_id).val() === null){
          jQuery("#"+error_id).text('Fields Select Agents and Select Metrice are mandatory.').show();
          return false;
        }
        else if(jQuery("#"+members_select_id).val().length > 4){
          jQuery("#"+error_id).text('Fields Select Agents can have only 4 values at max.').show();
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
          jQuery('#sliding').click();
          jQuery("#loading-box").removeClass('hide');
          jQuery('#report-filter-edit').hide();
          _FD.populate_charts();
        }
      });

      jQuery("#dialog-select-submit").live('click',function(event){
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
      filter_obj = eval(jQuery("input[name='selected_filter_data']").val());
      var filter_html = "<li>Filtered by:</li>";
      jQuery.each(filter_obj,function(index,value){
        filter_html += "<li>"+value['name']+" : <strong>"+value['value']+"</strong></li>";
      });
      filter_html += "<li>Time Period : <strong>"+jQuery("#"+_FD._const['date_field']).val()+"</strong></li>";
      jQuery("#"+_FD._const['filter_container']).html(filter_html);
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
        type: "POST",
        url: _FD._url+"/generate",
        dataType: "html",
        data: data,
        success: function(data){
          jQuery('#ticket-list-body-content').html(data);
          jQuery("#loading-box").addClass('hide');
        },
        error: function(data){
          jQuery('#ticket-list-body-content').text(data.statusText);
          jQuery("#loading-box").removeClass('hide');
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
        jQuery('#sliding').slide();
      }
   };  
})();