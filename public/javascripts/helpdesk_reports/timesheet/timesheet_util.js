var adjustingHeight = false;

Helpkit.TimesheetUtil = {} || Helpkit.TimesheetUtil;

Helpkit.TimesheetUtil = {
    MULTI_SELECT_SELECTION_LIMIT: 50,
    FILTER_LIMIT: 10,
    FILTER_LIMIT_MSG: I18n.t('helpdesk_reports.filter_error_msg'),
    reports_specific_disabled_filter:{},
    MAX_COLUMN_LIMIT : 10,
    COLUMN_LIMIT_FOR_PDF : 10,
    global_disabled_filter: [],
    default_available_filter : [],
    filter_remote : ["agent_id","company_id"],
    filter_remote_url : {
            "agent_id" : "agents",
            "company_id" : "companies",
            "tag_id" : "tags"
    },
    ATTACH_DEFAULT_FILTER : false,
    /* Time-outs for ajax requests in milliseconds,
    ** set to 1 min for now. Will be handled at backend later on.
    */
    timeouts: {
        main_request: 120000,
        glance_right_pane: 120000,
        ticket_list: 120000,
        custom_field: 120000
    },
    recordAnalytics : function(){

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

            var date_range = jQuery("#date_range").val().split('-');
            var diff = -1;
            var event_prop = {
              Date: jQuery("#date_range").val()
            };

            if (date_range.length == 2){
              diff = (new Date().setHours(0,0,0,0) - Date.parse(date_range[1])) / (36e5 * 24);
            } else{
               diff = (new Date().setHours(0,0,0,0) - Date.parse(date_range[0])) / (36e5 * 24);
            }

            if(diff == 0) {
              event_prop.today_used_in_range = true;
            }
            if(diff == 1) {
              event_prop.yesterday_used_in_range = true;
            }
            App.Report.Metrics.push_event("TimeSheet Report Generated", event_prop);
        });
    },
    getFilterDisplayData: function () {
        var _this = this;
        Helpkit.locals.select_hash = [];
        jQuery("#active-report-filters div.ff_item").map(function () {
            var container  = this.getAttribute("container");
            var data_label = this.getAttribute("data-label");
            var condition = this.getAttribute("condition");
            var value = [];

            if (container == "nested_field") {
                value = jQuery(this).children('select').find('option:selected').text();
            } else {
                //select
                if(jQuery.inArray(condition,_this.filter_remote) != -1) {
                    var data = jQuery(this).find(".filter_item").select2('data');
                    if(data != undefined && data.length > 0){
                        data.map(function(val,i){
                            value.push(val.text);
                        });
                    }
                } else {
                    value = jQuery(this).find('option:selected').map(function () {
                        return jQuery(this).text();
                    }).get();
                }
            }

            if ((data_label !== null) && value && value.length && ((container !== "nested_field") || ((container === "nested_field") && (value !== "...")))) {
                var values = (typeof value == "string") ? value.toString() : value.join(', ');
                var hash = {
                    name: data_label,
                    value: values
                };
                Helpkit.locals.select_hash.push(hash);
            }
        });
        _this.setFilterDisplayData();
    },
    setFilterDisplayData: function () {
        var tmpl = JST["helpdesk_reports/templates/filter_data_template"]({
            data: Helpkit.locals.select_hash
        });
        jQuery("#filter_text").html(tmpl);
        //trigger_event("report_refreshed",{});
    },
    setFilterData: function () {
        var _this = this;
        var locals = Helpkit.locals;
        locals.query_hash = [];
        locals.local_hash = [];

        jQuery("#active-report-filters div.ff_item").map(function () {
            var condition = this.getAttribute("condition");
            var container = this.getAttribute("container");
            var operator  = this.getAttribute("operator");
            var value = [];
            var isAjaxSourceSelect = false;
            var label;
            //Store the search results in localStorage, otherwise cant populate the filter on page refresh
            searchData = [];


            if(jQuery.inArray(condition,_this.filter_remote) != -1){
                isAjaxSourceSelect = true;
            }

            if (container == "nested_field") {
                value = (jQuery(this).children('select').val() === null ? "" : jQuery(this).children('select').val());
                label = jQuery(this).children('select').find('option:selected').text();
            } else if (container == "multi_select" || container == "select") {

                if(isAjaxSourceSelect){
                    value = jQuery(this).find(".filter_item").select2('val');
                    searchData = jQuery(this).find(".filter_item").select2('data');
                }else{
                    value = jQuery(this).find('option:selected').map(function () {
                        return this.value;
                    }).get();
                    label = jQuery(this).find('option:selected').map(function () {
                        return jQuery(this).text();
                    }).get();
                }
            }

            if (value.length) {
                var hash = {
                    condition: condition,
                    operator: operator,
                    value: value.toString()
                };
                hash.label = label;
                locals.query_hash.push(hash);
                //local_hash is filters stored in localStorage for populating on load.
                var local_hash = _this.getLocalHash(condition, container, operator, value,searchData);
                //local_hash.label = label;
                if(!jQuery.isEmptyObject(local_hash)){
                   locals.local_hash.push(local_hash);
                }
            } else {
                //Removing fields with no values in filters by triggering click.(only for non default fields)
                if(_this.default_available_filter.indexOf(condition) < 0){
                    var active = jQuery('#div_ff_' + condition);
                    if (active.attr('data-type') && active.attr('data-type') === "filter-field") {
                        _this.actions.removeField(active);
                    }
                }

            }
        });

    },
    afterFilterValidation: function () {
        var _this  = this;
        var locals = Helpkit.locals;

        if(locals.params != undefined) {
            jQuery.each(locals.params, function (index) {
                locals.params[index]['filter'] = locals.query_hash;
            });
        }
        // TODO: Consider mode this to a cache util.
        // Cache.get(key) / Cache.set(key, data)
        if (typeof (Storage) !== "undefined") {
            //Storing filters in localstorage
            window.localStorage.setItem('reports-filters', locals.local_hash.toJSON());
            //Storing the index of visited report to retain it.
            /*
            var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
            window.localStorage.setItem(Helpkit.locals.report_type,current_selected_index); */
        }
        _this.dateChanged();
        _this.actions.closeFilterMenu();
        _this.generate();
    },
    generate : function(){
          var _this = this;
          jQuery("#loading-box").show();
          jQuery("#time_sheet_report").css('opacity','0.2');
          jQuery("#loading-box").css('background','transparent');
          jQuery(".reports-loading").css('margin-top','330px');

          var group_by = {
              condition : 'group_by',
              value : Helpkit.locals.current_group_by == undefined ? 'customer_name' : Helpkit.locals.current_group_by
          }
          Helpkit.locals.query_hash.push(group_by);

          //Column selection
          var columns = [];
          jQuery.each(jQuery("[data-action=select-column] input:checked"),function(i,el){
              columns.push(jQuery(el).attr('id'));
          });
          Helpkit.locals.columns = columns;

          var params = {
              version : "v2",
              date_range : jQuery("#date_range").val(),
              report_filters : Helpkit.locals.query_hash,
              columns : columns
          };

          jQuery.ajax({
              url: '/reports/timesheet/report_filter',
              type: "POST",
              contentType: 'application/json',
              data: Browser.stringify(params),
              success: function(data){
                  jQuery("#loading-box").hide();
                  jQuery("#time_sheet_report").css('opacity','1');
                  jQuery("#time_sheet_report").removeClass('slide-shadow');
                  //Markup replaced on submit so copy and re insert
                  var save_menu = jQuery('#reports_type_menu').html();
                  var title_block = jQuery('#report-title').html();

                  jQuery("#time_sheet_report").html(data);
                  jQuery('#reports_type_menu').html(save_menu);
                  jQuery('#report-title').html(title_block);
                  trigger_event("report_refreshed",{});

                  var hours_tracked = jQuery('h1.total_time_metric').html().trim();
                  var billabe_hours = jQuery('h1.billable_time').html().trim();
                  var non_billable_hours = jQuery('h1.nonbillable_time').html().trim();
                  var size = _this.calculateBestFontSize(hours_tracked);
                  _this.adjustFontSize('h1.total_time_metric',size);
                  _this.adjustFontSize('h1.billable_time',size);
                  _this.adjustFontSize('h1.nonbillable_time',size);
                  _this.bindEvents();
                  _this.getFilterDisplayData();
                },
                error: function (data) {
                  _this.bindEvents();
                  jQuery("#loading-box").hide();
                  jQuery("#time_sheet_report").css('opacity','1');
                  jQuery("#time_sheet_report").removeClass('slide-shadow');
                  var text = I18n.t('helpdesk_reports.something_went_wrong_msg');
                  showResponseMessage(text);
                }
          });
    },
    getRemoteFilterConfig : function(condition,initFromSavedReportData,initData){
         var _this = this;
         var include_none = true;
         var noneVal = "-None-" ;
         var none_value = -1;

         var config = {
            maximumSelectionSize: _this.MULTI_SELECT_SELECTION_LIMIT
         };
         config.ajax = {
            url: "/search/autocomplete/" + _this.filter_remote_url[condition],
            dataType: 'json',
            delay: 250,
            data: function (term, page) {
                searchText = term;
                return {
                    q: term, // search term
                };
            },
            results: function (data, params) {
                      var results = [];
                      jQuery.each(data.results, function(index, item){
                        if(condition == "agent_id") {
                            results.push({
                              id: item.user_id,
                              text: item.value
                            });
                        } else {
                            results.push({
                              id: item.id,
                              text: item.value
                            });
                        }
                      });
                      if(condition == "agent_id") {
                            if(include_none && noneVal.toLowerCase().indexOf(searchText.toLowerCase()) > -1){
                                results.push({
                                    id: -1,
                                    text: noneVal
                                });
                            }
                     }
                      return {
                        results: results
                      };
            },
            cache: true
          };
          config.multiple = true ;
          config.minimumInputLength = 2 ;
          config.initSelection = function (element, callback) {
                if(initFromSavedReportData){
                    callback(initData);
                } else {
                    if (typeof (Storage) !== "undefined" && localStorage.getItem('reports-filters') !== null) {
                        var filter = JSON.parse(localStorage.getItem('reports-filters'));
                        jQuery.each(filter, function(i,obj){
                            if(obj.condition == condition){
                                if(obj.source != undefined) {
                                    callback(obj.source);
                                }
                                return false;
                            }
                        });
                    }
                }
            };
        return config;
    },
    getLocalHash: function (condition, container, operator, value,searchData) {
        var locals =  Helpkit.locals;
        var hash = {};
        if (container === 'nested_field' && locals.custom_field_hash.hasOwnProperty(condition)) {
            var nested_values = [];
            var nested_labels = [];
            for (i = 0; i < locals.custom_field_hash[condition].length; i++) {
                var values = jQuery('#div_ff_' + locals.custom_field_hash[condition][i]).find('select').val();
                var labels = jQuery('#div_ff_' + locals.custom_field_hash[condition][i]).children('select').find('option:selected').text();
                nested_values.push(values);
                nested_labels.push(labels);
            }
            hash = {
                condition: condition,
                operator: operator,
                value: nested_values,
                label: nested_labels
            };
        } else if (container !== 'nested_field') {
            hash = {
                condition: condition,
                operator: operator,
                value: value.toString()
            };
        }

        if(searchData != undefined && searchData.length > 0){
            hash.source = searchData;
        }
        return hash;
    },
    dateChanged: function () {
        var locals    = Helpkit.locals;
        var date      = jQuery('#date_range').val();
        if(Helpkit.locals.is_non_sprout_plan){
            date  = jQuery('#date_range').val();
        } else {
            date = jQuery('#sprout-datepicker').val();
        }
        //var preRanges = locals.presetRangesSelected;
        locals.date_range = date;
        if(locals.params != undefined) {
            jQuery.each(locals.params, function (index) {
                locals.params[index]['date_range'] = date;
            });
        }
    },
    refreshReports: function () {
        var _this = this;
        var locals = Helpkit.locals;

        _this.setFilterData();

        if ( locals.query_hash.length <= _this.FILTER_LIMIT ) {

            _this.flushErrorMsg();
            _this.afterFilterValidation();

            return true;

        } else {

            _this.showErrorMsg();

            if(!jQuery("#report-filters").is(":visible")){
                _this.actions.openFilterMenu();
            }

            return false;

        }

    },
    showErrorMsg: function () {
        var msg = this.FILTER_LIMIT_MSG;
        jQuery('#filter_validation_errors .error-msg').text(msg);
    },
    flushErrorMsg: function () {
        jQuery('#filter_validation_errors .error-msg').text('');
    },
    makeAjaxRequest: function (args) {
        args.url = args.url;
        args.type = args.type ? args.type : "POST";
        args.dataType = args.dataType ? args.dataType : "json";
        args.data = args.data;
        args.success = args.success ? args.success : function () {};
        args.error = args.error ? args.error : function () {};
        var _request = jQuery.ajax(args);
    },
    calculateBestFontSize : function(content) {
        var len = 0;
        if(content.indexOf('.') == -1) {
          len = content.length;
        } else {
          len = content.indexOf('.')+3
        }
        if(len <= 12) {
            return '36px';
        } else if( len <= 24){
            return '26px';
        } else {
            return '16px';
        }
    },
    adjustFontSize : function(el,size) {
        jQuery(el).css('font-size',size);
    },
    bindEvents: function () {
        var _this = this;
        var $report_page = jQuery('#report-page');
        var $document = jQuery(document);

        $document.off('.helpdesk_reports');

        jQuery("#export_as_csv").on('click.helpdesk_reports',function(){
                var params = _this.getPdfParams();
                jQuery("[name=filters]").val(Browser.stringify(params));
                jQuery("#generate-pdf").trigger("click");
        });
        jQuery("#export_pdf").on('click.helpdesk_reports',function(){
          var params = _this.getPdfParams();
          jQuery.ajax({
              url: Helpkit.locals.export_pdf_url,
              contentType: 'application/json',
              type: "POST",
              data: Browser.stringify(params),
              success: function(data) {
                   var msg = I18n.t('adv_reports.report_export_success');
                   var text = "<span id='email-reports-msg'>"+msg+"</span>";
                   showResponseMessage(text);
                },
                error: function (data) {
                  jQuery("#loading-box").hide();
                  jQuery("#time_sheet_report").css('opacity','1');
                  jQuery("#time_sheet_report").removeClass('slide-shadow');
                  var text = I18n.t('helpdesk_reports.something_went_wrong_msg');
                  showResponseMessage(text);
                }
          });
        });

        jQuery(document).on("presetRangesSelected", function(event,data) {
            Helpkit.presetRangesSelected = data.status;
            is_preset_selected = data.status;
        });

        jQuery(document).on('click.helpdesk_reports', '[data-action="add-filter"]', function () {
            _this.actions.toggleFilterListMenu();
        });
        jQuery(document).on('click.helpdesk_reports', '[data-action="pop-field"]', function () {
            var selected = jQuery(this).data('menu');
            _this.actions.constructReportField(selected);
        });
        jQuery(document).on('click.helpdesk_reports', '[data-action="remove-field"]', function () {
            _this.actions.removeField(this);
            trigger_event("filter_changed");
        });

        jQuery(document).on('click.helpdesk_reports', '[data-action="open-filter-menu"]', function () {
            //Each Report Util will set whether to attach default filters to the active menu on init function
            _this.actions.openFilterMenu();
        });
        jQuery(document).on('click.helpdesk_reports', '[data-action="close-filter-menu"]', function () {
            _this.actions.closeFilterMenu();
        });

        jQuery(document).on('keypress.helpdesk_reports keyup.helpdesk_reports keydown.helpdesk_reports', "#date_range", function (ev) {
            _this.actions.disableKeyPress(ev);
        });

        jQuery(document).on('click.helpdesk_reports', '[data-action="reports-submit"]', function () {
            _this.refreshReports();
        });

        jQuery(document).on('change.helpdesk_reports','#group_by_field',function(){
            jQuery('#group_by').val(jQuery('#group_by_field').val());
            Helpkit.locals.current_group_by = jQuery('#group_by_field').val();
            _this.refreshReports();
        });

        jQuery(document).on('click.helpdesk_reports', '[data-action="pop-report-type-menu"]', function (event) {
              event.stopImmediatePropagation();
              var menu = jQuery('#reports_type_menu');
              var hash = Helpkit.report_filter_data;
              if(hash.length == 0 || ( hash.length == 1 && Helpkit.commonSavedReportUtil.default_report_is_scheduled)){

              }else{
                  if (!menu.is(':visible')) {
                      menu.removeClass('hide');
                  } else {
                      menu.addClass('hide');
                  }
              }
        });

        jQuery(document).on('click.helpdesk_reports', function () {
            var menu = jQuery('#reports_type_menu');
            if (menu.is(':visible')) {
                menu.addClass('hide');
            }
        });

        $document.on("presetRangesSelected", function(event,data) {
            Helpkit.locals.presetRangesSelected = data.status;
            Helpkit.locals.presetRangesPeriod = data.period;
        });

        jQuery(document).on('click.helpdesk_reports', '[data-action="show-column-selection"]', function () {
            jQuery('.picker').slideToggle();
        });
        $document.on('mousemove.helpdesk_reports', '.picker', function(event) {
            event.preventDefault();
            //jQuery('body').addClass('preventscroll');
        });
        $document.on('mouseleave.helpdesk_reports', '.picker', function(event) {
            event.preventDefault();
            //jQuery('body').removeClass('preventscroll');
        });

        $document.on('click.helpdesk_reports','[data-action=submit-column-selection]',function(){
              _this.refreshReports();
        });

        $document.on('click.helpdesk_reports','[data-action=select-column]',function(){
             var no_of_selections = jQuery("[data-action=select-column] input:checked").length;
             if(no_of_selections <= _this.MAX_COLUMN_LIMIT ) {
                jQuery('.picker .limit-error').addClass("hide");
                //jQuery('[data-action=submit-column-selection]').removeClass('disabled');
             } else {
                jQuery('.picker .limit-error').removeClass("hide");
                //jQuery('[data-action=submit-column-selection]').addClass('disabled');
                return false;
             }
             _this.toggleArchiveMessage();
        });

        _this.onInitialLoad();
        _this.construct_metric_graph();
        _this.construct_column_selection();
        _this.actions.addIndexToFields();
        _this.actions.customFieldHash();
        _this.actions.generateReportFiltersMenu();
        //_this.actions.scrollTop();
    },
    toggleArchiveMessage : function() {
        //Check if custom column is selected
        if(Helpkit.locals.archive_enabled) {
            var is_custom_column_selected = jQuery("[data-action=select-column] input:checked[data-custom-column=true]").length > 0 ? true : false;
            if(is_custom_column_selected) {
                jQuery('.picker .limit-error').addClass('hide');
                jQuery('.picker .archive-error').removeClass('hide');
            } else {
                jQuery('.picker .archive-error').addClass('hide');
            }

            var active_filters = jQuery("#active-report-filters .filter-field");
            var is_custom_filter_used =  false;
            jQuery.each(active_filters,function(i,el){
                if(jQuery.inArray(jQuery(el).attr('condition') , Helpkit.locals.custom_filter) != -1){
                    is_custom_filter_used = true;
                }
            });
            if(is_custom_filter_used) {
                jQuery('#filter_validation_errors .error-msg').text('Filtering by custom fields will exclude archive tickets');
            } else {
                jQuery('#filter_validation_errors .error-msg').text('');
            }  
        }
    },
    getPdfParams :function() {
        var remove = [];
        var params = {};
        params.data_hash = {};
        params.data_hash.version = 'v2';
        params.data_hash.date = {}
        params.data_hash.date.date_range = jQuery("#date_range").val();
        params.data_hash.date.presetRange = false;
        if(Helpkit.locals.query_hash != undefined) {
            params.data_hash.report_filters = Helpkit.locals.query_hash;
        } else {
            params.data_hash.report_filters = [
              { "condition":"group_by","value":"customer_name"}
            ]
        }
        
        params.data_hash.select_hash = Helpkit.locals.select_hash;
        if(savedReportUtil.last_applied_saved_report_index != -1){
          params.filter_name = Helpkit.report_filter_data[parseInt(savedReportUtil.last_applied_saved_report_index)].report_filter.filter_name;
        }
        //Column selection
        var columns = [];
        jQuery.each(jQuery("[data-action=select-column] input:checked"),function(i,el){
            columns.push(jQuery(el).attr('id'));
        });
        params.data_hash.columns = columns;

        return params;
    },
    onInitialLoad : function() {
        var self = this;
        var metric_hash = Helpkit.locals.metric_hash;
        self.adjustFontSize(metric_hash['hours_tracked'],'h1.total_time_metric');
        self.adjustFontSize(metric_hash['billabe_hours'],'h1.billable_time');
        self.adjustFontSize(metric_hash['non_billable_hours'],'h1.nonbillable_time');
    },
    construct_metric_graph : function() {

        var chart_data = Helpkit.locals.metric_hash['barchart_data'];

        if(chart_data.length > 0 ){

          jQuery('#bar_chart_noinfo').hide();
          var billabale = chart_data[1]['data'][0];
          var non_billable = chart_data[0]['data'][0];
          var total = billabale + non_billable;
          var billabale_perc = billabale != 0 ? Math.round(( 100 * billabale) / total) : 0;
          var non_billable_perc = Math.round(100 - billabale_perc);
          var width = billabale_perc + '%';
          jQuery(".comparision_chart .billable").width(width);
          jQuery(".comparision_chart .billable_value").html(width);

          //Tooltip
          jQuery(".comparision_chart").twipsy({
            html : true,
            placement : "above",
            title : function() {
              return "<div class='metric_tooltip billable'><div class='type'>Billable</div><div class='value'>" + billabale_perc + "%</div></div><div class='metric_tooltip non-billable'><div class='type'>Non-Billable</div><div class='value'>" + non_billable_perc + "%</div></div><div class='clear'></div>" }
          });
        } else {
          jQuery('.comparision_chart').hide();
        }
    },
    construct_column_selection : function() {
        var self = this;
        var hash = Helpkit.report_filter_data;

        var tmpl = JST["helpdesk_reports/templates/timesheet_column"]({
                data: Helpkit.locals.report_column_hash
        });
        jQuery('[rel=column_items]').html(tmpl);
        jQuery("[data-action=select-column] input").attr("checked",false);

        var columns = [];
        var defaults = Helpkit.locals.report_column_hash.filter(function(o){
            if(o.default == true) {
              return true;
            } else {
               return false
            }
        }).map(function(o){ return o.name});

        if(savedReportUtil.filterChanged) {
            columns = Helpkit.locals.columns;
        } else {
            var index = savedReportUtil.last_applied_saved_report_index;
            if( index != -1) {
              columns = hash[index].report_filter.data_hash.columns != undefined ? hash[index].report_filter.data_hash.columns : defaults;
            } else {
              columns = defaults;
            }
        }
        //console.log(columns);
        jQuery.each(columns,function(i,el) {
            var query = "li[data-action=select-column] input#" + el;
            jQuery(query).attr('checked','checked');
        });

        //Add Divider
        jQuery('[data-custom-column="true"]:first').parent().addClass('divider');
        self.toggleArchiveMessage();
    },
    actions : {
        closeFilterMenu: function () {
            if(jQuery('#inner').hasClass('openedit')){
                jQuery('#inner').removeClass('openedit');
                setTimeout(function(){
                   jQuery("#report-filters").hide();
                }, 100);
            }
            if (jQuery("#report_fields_list").is(':visible')) {
                jQuery("#report_fields_list").hide();
            }
        },
        openFilterMenu: function () {
            jQuery("#report-filters").scrollTop(0);
            jQuery("#report-filters").show();
            jQuery('#inner').addClass('openedit');
        },
        toggleFilterListMenu: function () {
            var _this = this;
            var menu = "#report_fields_list";
            if (!jQuery(menu).is(':visible') && jQuery(menu + ' li').length !== 0) {
                jQuery(menu).show();
            } else {
                jQuery(menu).hide();
            }
        },
        toggleMoreButton : function() {
            var locals = Helpkit.locals;
            var $more_button = jQuery(".report-fields-selector");
            var selected_options = jQuery(".filter-field").length;
            var field_options = locals.custom_fields_feature_enabled ? _.keys(locals.report_field_hash).length : _.keys(locals.report_field_hash).length - _.keys(locals.custom_field_hash).length;
            if( field_options == selected_options ) {
                $more_button.hide();
            } else {
                $more_button.show();
            }
        },
        removeField: function (active) {
            var _this = this;
            var field = jQuery(active).closest("[data-type='filter-field']");
            _this.removeReportField(field.attr('condition'), field.attr('data-label'));
            Helpkit.TimesheetUtil.toggleArchiveMessage();
        },
        disableKeyPress: function (ev) {
            ev.preventDefault();
            return false;
        },
        addIndexToFields: function () {
            var hash = Helpkit.locals.report_field_hash;
            var index = 0;
            for (var key in hash) {
                hash[key].position = index;
                index++;
            }
        },
        generateReportFiltersMenu: function () {
            var _this = this;
            var locals = Helpkit.locals;
            var temp_hash = {};

            jQuery.each(locals.report_field_hash,function(idx,item) {
                if(locals.custom_fields_feature_enabled) {
                    temp_hash[item.condition] = item;
                } else {
                    if(jQuery.inArray(item.condition,locals.custom_filter) == -1) {
                        temp_hash[item.condition] = item;
                    }
                }
            });

            var menu_tmpl = JST["helpdesk_reports/templates/filter_menu_timesheet"]({
                data: temp_hash
            });
            jQuery("#report_fields_list ul").html(menu_tmpl);
            // Flush those options from menu those were added by addFiltersToMenu
            jQuery("#active-report-filters div.ff_item").map(function() {
                  var condition = this.getAttribute("condition");
                  var container = this.getAttribute("container");
                  var operator  = this.getAttribute("operator");
                  _this.removeFieldFromMenu(condition);
            });
        },
        customFieldHash: function () {
            var locals = Helpkit.locals;
            var hash = locals.report_field_hash;
            locals.custom_field_hash = {};
            for (var key in hash) {
                if (hash[key]['field_type'] === 'custom' && hash[key]['container'] === 'nested_field') {
                    var fields = [];
                    fields.push(hash[key]['condition']);
                    for (i = 0; i < hash[key]['nested_fields'].length; i++) {
                        fields.push(hash[key]['nested_fields'][i]['condition']);
                    }
                    locals.custom_field_hash[key] = fields;
                } else if (hash[key]['field_type'] === 'custom' && hash[key]['container'] === 'multi_select') {
                    locals.custom_field_hash[key] = [];
                }
            }
        },
        constructReportField: function (field, val) {
            var _this = this;
            var _this_hash = Helpkit.locals.report_field_hash;
            var val = val || "";
            var present = jQuery('#active-report-filters').find(jQuery('[condition=' + field + ']'));
            if (field in _this_hash && !present.length) {
                var field_hash = _this_hash[field];
                field_hash.active = true;
                if (field_hash.container && field_hash.container === 'nested_field') {
                    _this.constructNestedField(field_hash, val);
                } else {
                    _this.constructMultiSelect(field_hash, val);
                }
                _this.removeFieldFromMenu(field);
            }
            Helpkit.TimesheetUtil.toggleArchiveMessage();
            _this.hideFilterMenu();
            _this.toggleMoreButton();
        },
        constructNestedField: function (field_hash, val) {
            var _this = this;
            var tmpl = JST["helpdesk_reports/templates/nested_field_tmpl"](field_hash);
            jQuery(tmpl).appendTo('#active-report-filters');
            jQuery('#' + field_hash.field_id + '_category').nested_select_tag({
                initValues: _this.nestedFieldInitValues(val),
                default_option: "<option value=''>...</option>",
                data_tree: field_hash.options,
                subcategory_id: field_hash.field_id + '_sub_category',
                item_id: field_hash.field_id + '_item_sub_category'
            });
        },
        constructMultiSelect: function (field_hash, val) {
            var _this = this;
            var util = Helpkit.TimesheetUtil;
            var tmpl = JST["helpdesk_reports/templates/multiselect_others_tmpl"](field_hash);
            jQuery(tmpl).appendTo('#active-report-filters');

            var config = {
                maximumSelectionSize: util.MULTI_SELECT_SELECTION_LIMIT
            };
            if(jQuery.inArray(field_hash.condition,util.filter_remote) != -1){
                config = util.getRemoteFilterConfig(field_hash.condition,false);
            }
            jQuery("#" + field_hash.condition + ".filter_item").select2(config);
            if (val.length) {
                jQuery("#" + field_hash.condition + ".filter_item").select2('val', val.split(','));
            }
        },
        nestedFieldInitValues: function (val) {
            var init = {
                "category_val"    : val.length && val[0] !== null ? val[0] : null,
                "subcategory_val" : val.length && val[1] !== null ? val[1] : null,
                "item_val"        : val.length && val[2] !== null ? val[2] : null
            }

            return init;
        },
        hideFilterMenu: function () {
            if (!jQuery("[data-action='pop-field']").length) {
                //jQuery("[data-action='add-filter']").hide();
                jQuery("#report_fields_list").hide();
            }
        },
        removeFieldFromMenu: function (field) {
            var _this = this;
            jQuery('li[data-menu="' + field + '"]').remove();
        },
        removeReportField: function (condition, dataLabel) {
            var _this = this;
            if (condition.length && dataLabel.length && !jQuery('[data-menu="' + condition + '"]').length) {
                jQuery('#div_ff_' + condition).remove();
                var field = '<li data-position="' + Helpkit.locals.report_field_hash[condition].position + '" data-action="pop-field" data-menu="' + condition + '">' + escapeHtml(dataLabel) + '</li>';
                jQuery("#report_fields_list" + " ul").append(field);
                Helpkit.locals.report_field_hash[condition]["active"] = false;
            }
            _this.sortFilterMenu();
            _this.checkFilterOptions();
        },
        sortFilterMenu: function () {
            var list = jQuery("[data-action='pop-field']");
            var listItems = list.sort(function (a, b) {
                return (jQuery(b).data('position')) < (jQuery(a).data('position')) ? 1 : -1;
            }).appendTo('#report_fields_list ul');
        },
        checkFilterOptions: function () {
            //Show filter menu when all fields not selected
            if (jQuery("[data-action='pop-field']").length && !jQuery("[data-action='add-filter']").is(':visible')) {
                jQuery("[data-action='add-filter']").show();
            }
        },
        setReportFilters: function () {
            var _this = this;
            var util = Helpkit.TimesheetUtil;
            var filter = [];
            var dateDiff = 29;
            var daterange;

            if (typeof (Storage) !== "undefined" && localStorage.getItem('reports-filters') !== null) {
                filter = JSON.parse(localStorage.getItem('reports-filters'));
            }
            //daterange = this.convertDateDiffToDate(dateDiff);

            //Each report will decide, whether to add default filters or not to active menu ( agent,group,customer)
            if(util.ATTACH_DEFAULT_FILTER) {

                util.ATTACH_DEFAULT_FILTER = false;

                //Add default filter fields to list
                var defaultFilters = util.default_available_filter;
                _.each(defaultFilters,function(el,idx){
                    //check if the default filter was used,
                    //if so populate the report field with value else popoulate field with empty
                    var filter_contains_default = false;
                    var filter_value = "";
                    if (filter.length) {
                        jQuery(filter).each(function (index, hash) {
                            if (Helpkit.locals.report_field_hash.hasOwnProperty(hash.condition) && _this.global_disabled_filter.indexOf(hash.condition) < 0 && (_this.reports_specific_disabled_filter[HelpdeskReports.locals.report_type] || []).indexOf(hash.condition) < 0) {
                                if(el == hash.condition){
                                   //Filter has been applied to default field
                                   filter_contains_default  = true;
                                   filter_value = hash.value;
                                   return false; //break the loop
                                }

                            }
                        });
                    }
                    if(filter_contains_default){
                        _this.constructReportField(el);//,filter_value);
                    } else {
                         _this.constructReportField(el);
                    }
                });
            }
            //Duplicates will not be inserted, Condition checking in constructReportField function
            if (filter.length) {
                jQuery(filter).each(function (index, hash) {
                    if (Helpkit.locals.report_field_hash.hasOwnProperty(hash.condition) && _this.global_disabled_filter.indexOf(hash.condition) < 0 && (_this.reports_specific_disabled_filter[Helpkit.locals.report_type] || []).indexOf(hash.condition) < 0) {
                        _this.constructReportField(hash.condition)//,hash.value);
                    }
                });
            }

            jQuery('#date_range').val(daterange);
            jQuery('#sprout-datepicker').val(daterange);
            var date = jQuery('#date_range').val();
            _this.constructDateRangePicker();

            //HelpdeskReports.SavedReportUtil.init(-1);
            return date;
        },
        showWrappers: function () {
            jQuery('#view_more_wrapper').removeClass('hide');
            jQuery('#reports_wrapper').removeClass('hide');
            jQuery('#ticket_list_wrapper').removeClass('hide');
            jQuery('#loading-box').hide();
        },
        flushLocals: function () {
            Helpkit.locals = {};
        },
        adjustFilterButton : function() {
            if(Helpkit.locals.is_non_sprout_plan) {
                var lang = jQuery("html").attr("lang");
                if(lang && lang == "zh-TW") {
                    jQuery(".edit-filter").removeClass('span1').addClass('span2');
                    jQuery(".filter-type").removeClass('span11').addClass('span10');
                }
            }
        },
        showErrorMsg: function () {
          var msg = this.FILTER_LIMIT_MSG;
          jQuery('#filter_validation_errors .error-msg').text(msg);
        },
        flushErrorMsg: function () {
            jQuery('#filter_validation_errors .error-msg').text('');
        }
    },
    init : function() {
        var self = this;
        this.bindEvents();
        savedReportUtil.init();
    }
}

var savedReportUtil = (function() {

    var _FD = {
        last_applied_saved_report_index : -1,
        CONST: {
            base_url : "/reports/timesheet",
            save_report   : "/save_reports_filter",
            delete_report : "/delete_reports_filter",
            update_report : "/update_reports_filter"
        },
        save_util : Helpkit.commonSavedReportUtil,
        remote_filters : ["customers_filter"],
        filters : [ "customers_filter","user_id" ,"billable","group_id","products_id","ticket_type","priority","group_by_field"],
        filterChanged : false,
        bindSavedReportEvents : function() {
            var _this = this;

            jQuery(document).on('change', '#customers_filter,.filter_item,.ff_item', function (ev) {
                 if(ev.target && ev.target.id != "group_by_field" && !adjustingHeight){
                    _this.filterChanged = true;
                    _this.save_util.filterChanged = true;
                    _this.setFlag('false');
                 }
                 adjustingHeight = false;
            });

            jQuery(document).on('click', '[data-action=select-column] input', function (ev) {
                    _this.filterChanged = true;
                    _this.save_util.filterChanged = true;
            });

            jQuery(document).on("save.report",function() {
              _this.saveReport();
            });
            jQuery(document).on("delete.report",function() {
              _this.deleteSavedReport();
            })
            jQuery(document).on("edit.report",function(ev,data) {
              _this.updateSavedReport(data.isNameUpdate);
            });
            jQuery(document).on("discard_changes.report",function() {
              _this.discardChanges();
            });
            jQuery(document).on("apply.report",function(ev,data) {
              jQuery('[data-action="pop-report-type-menu"]').trigger('click');
              _this.applySavedReport(data.index);
            });
            jQuery(document).on("filter_changed",function(ev,data){
                _this.filterChanged = true;
                _this.save_util.filterChanged = true;
                _this.setFlag('false');
            });
            jQuery(document).on("report_refreshed",function(ev,data){
                if(_this.filterChanged && !adjustingHeight) {
                     _this.save_util.controls.hideDeleteAndEditOptions();
                     _this.save_util.controls.hideScheduleOptions();
                     _this.save_util.controls.showSaveOptions(_this.last_applied_saved_report_index);
                     _this.addFiltersToMenu(true);
                } else{
                  var index = parseInt(jQuery('.active [data-action="select-saved-report"]').attr('data-index'));
                  _this.save_util.showReportDropdown();
                  if(index != -1) {
                      _this.save_util.controls.showDeleteAndEditOptions();
                      var columns_condition = Helpkit.TimesheetUtil.COLUMN_LIMIT_FOR_PDF >= (Helpkit.locals.colspan + 1);
                      if(is_preset_selected && columns_condition ){
                        _this.save_util.controls.showScheduleOptions(false);
                      } else{
                        _this.save_util.controls.hideScheduleOptions();
                      }
                      //Repopulate the filters because of bad code
                      //Full markup is replaced on every generate
                      //populate the filters from report filter data
                      _this.addFiltersToMenu(false);
                      Helpkit.TimesheetUtil.toggleArchiveMessage();
                  }
                  var result = Helpkit.ScheduleUtil.isScheduled(
                              _this.last_applied_saved_report_index,
                              _this.save_util.default_report_is_scheduled,
                              _this.save_util.default_index,
                              Helpkit.report_filter_data
                              );
                  if(result.is_scheduled){
                    Helpkit.ScheduleUtil.displayScheduleStatus(true,result.tooltip_title);
                  } else{
                    Helpkit.ScheduleUtil.displayScheduleStatus(false);
                  }
                }
            });
        },
        saveReport : function() {
              var _this = this;
              var opts = {
                  url: _this.CONST.base_url + _this.CONST.save_report,
                  callbacks : {
                     success: function () {
                          //update the last applied filter
                          _this.last_applied_saved_report_index = this.new_id;
                          _this.filterChanged = false;
                          _this.save_util.filterChanged = false;
                     },error: function () {}
                  },
                  params : _this.getParams()
                 };

              _this.save_util.saveHelper(opts);

              //Timesheet specific
              var columns_condition = Helpkit.TimesheetUtil.COLUMN_LIMIT_FOR_PDF >= (Helpkit.locals.colspan + 1);
              if(columns_condition){
                _this.save_util.controls.showScheduleOptions(false);
              } else {
                _this.save_util.controls.hideScheduleOptions();
              }

        },
        getParams : function() {
          var params = {};
          var _this = this;

          params.data_hash = {};
          params.data_hash.version = 'v2';
          var dateRange = jQuery("#date_range").val();

          params.data_hash.date = {};
          if(Helpkit.presetRangesSelected) {
               params.data_hash.date.date_range = _this.save_util.dateRangeDiff(dateRange);
               params.data_hash.date.presetRange = true;
               params.data_hash.date.period = Helpkit.presetRangesPeriod;
          } else {
               params.data_hash.date.date_range = dateRange;
               params.data_hash.date.presetRange = false;
          }
          //Only first page load we set date range to last 30 days, so its a presetRange
          if(Helpkit.presetRangesSelected == undefined) {
              params.data_hash.date.date_range = _this.save_util.dateRangeDiff(dateRange);
              params.data_hash.date.presetRange = true;
              params.data_hash.date.period = 'last_30';
          }

          params.data_hash.report_filters = Helpkit.locals.local_hash;
          var group_by = {
              condition : 'group_by',
              value : Helpkit.locals.current_group_by == undefined ? 'customer_name' : Helpkit.locals.current_group_by
          }
          params.data_hash.report_filters.push(group_by);
          params.data_hash.select_hash = Helpkit.locals.select_hash;
          if(_this.last_applied_saved_report_index == -1 && !_this.filterChanged) {
            params.data_hash.default_report_is_scheduled = true;
          }
          //Add list of columns to saved report
          params.data_hash.columns = Helpkit.locals.columns;
          return params;
        },
        updateSavedReport : function(isUpdateTitle) {
              var _this = this;

              var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
              var params = _this.getParams();
              var dateRange = jQuery("#date_range").val();

              if(current_selected_index == -1) {
                 current_selected_index = _this.save_util.default_index;
                 params.data_hash.default_report_is_scheduled = true;
              }

              if(is_scheduled_op){
                    params.filter_name = Helpkit.report_filter_data[current_selected_index].report_filter.filter_name;
                    params.data_hash.schedule_config = Helpkit.ScheduleUtil.getScheduleParams();
                    params.data_hash.date = Helpkit.report_filter_data[current_selected_index].report_filter.data_hash.date;
              } else {

                if(isUpdateTitle) {
                    params.filter_name = _this.save_util.escapeString(jQuery("#filter_name_save").val());
                    params.data_hash.schedule_config = Helpkit.report_filter_data[current_selected_index].report_filter.data_hash.schedule_config;
                    params.data_hash.date = Helpkit.report_filter_data[current_selected_index].report_filter.data_hash.date;
                  } else {
                    params.filter_name = Helpkit.report_filter_data[current_selected_index].report_filter.filter_name;
                    params.data_hash.schedule_config = Helpkit.report_filter_data[current_selected_index].report_filter.data_hash.schedule_config;
                    params.data_hash.date = {};

                    if(Helpkit.presetRangesSelected) {
                        params.data_hash.date.date_range = _this.save_util.dateRangeDiff(dateRange);
                        params.data_hash.date.presetRange = true;
                        params.data_hash.date.period = Helpkit.presetRangesPeriod;
                      } else {
                        params.data_hash.date.date_range = dateRange;
                        params.data_hash.date.presetRange = false;
                      }
                  }
              }
              params.id = Helpkit.report_filter_data[current_selected_index].report_filter.id;

              var opts = {
                  current_selected_index : current_selected_index,
                  url: _this.CONST.base_url + _this.CONST.update_report,
                  callbacks : {
                     success: function () {
                      _this.filterChanged = false
                     },
                     error: function (data) {
                      }
                  },
                  params : params
              };
              _this.save_util.updateHelper(opts);
        },
        deleteSavedReport : function() {
              var _this = this;
              var current_selected_index = parseInt(jQuery(".reports-menu li.active a").attr('data-index'));
              _this.flushAppliedFilters();

              var opts = {
                  current_selected_index : current_selected_index,
                  url: _this.CONST.base_url + _this.CONST.delete_report,
                  callbacks : {
                    success: function (resp) {
                      _this.applySavedReport(-1);
                    },
                    error: function (data){}
                  }
              };
              _this.save_util.deleteHelper(opts);
        },
        discardChanges : function() {
          this.applySavedReport(this.last_applied_saved_report_index);
          this.save_util.controls.hideSaveOptions();
        },
        applySavedReport : function(index) {

            var hash = Helpkit.report_filter_data;
            var _this = this;
            var invalid_params_found = false;
            is_preset_selected = false;

            _this.flushAppliedFilters();
            _this.last_applied_saved_report_index = index;
            _this.save_util.last_applied_saved_report_index = index;
            var id = -1;

            if(index != -1) {

                var filter_hash = hash[index].report_filter;
                id = filter_hash.id;
                if(filter_hash.data_hash.date.presetRange) {
                    //Set the date range from saved range
                    var daterange = _this.save_util.convertPresetRangesToDate(filter_hash.data_hash.date.date_range,filter_hash.data_hash.date.period);
                    jQuery('#date_range').val(daterange);
                    Helpkit.presetRangesSelected = true;
                    Helpkit.presetRangesPeriod = filter_hash.data_hash.date.period;
                    is_preset_selected = true;
                }else{
                    jQuery('#date_range').val(filter_hash.data_hash.date.date_range);
                    Helpkit.presetRangesSelected = false;
                    is_preset_selected = false;
                }

                if(filter_hash.data_hash.report_filters != null) {
                    _this.addFiltersToMenu(false);
                }
            } else {
              var default_date_range = _this.save_util.convertDateDiffToDate(29);
              jQuery('#date_range').val(default_date_range);
              Helpkit.presetRangesSelected = true;
              Helpkit.presetRangesPeriod = 'last_30';
              Helpkit.locals.columns.length = 0;
            }
            _this.save_util.setActiveSavedReport(jQuery(".reports-menu li a[data-index=" + index +"]"));
            _this.filterChanged = false;
             _this.save_util.filterChanged = false;
              //Set the flag that saved report was used
            _this.setFlag('true');

            //Column selection code
            var columns = [];
            var defaults = Helpkit.locals.report_column_hash.filter(function(o){
                if(o.default == true) {
                  return true;
                } else {
                   return false
                }
            }).map(function(o){ return o.name});

            var index = savedReportUtil.last_applied_saved_report_index;
            if( index != -1) {
              columns = hash[index].report_filter.data_hash.columns != undefined ? hash[index].report_filter.data_hash.columns : defaults;
            } else {
              columns = defaults;
            }

            jQuery.each(columns,function(i,el) {
                var query = "li[data-action=select-column] input#" + el;
                jQuery(query).attr('checked','checked');
            });

             Helpkit.TimesheetUtil.refreshReports();
            _this.save_util.cacheLastAppliedReport(id);

            _this.save_util.controls.hideSaveOptions();
            if(index != -1) {
                _this.save_util.controls.showDeleteAndEditOptions();
                _this.save_util.controls.showScheduleOptions(false);
            } else{
              _this.save_util.controls.hideDeleteAndEditOptions();
              _this.save_util.controls.showScheduleOptions(true);
            }
            var result = Helpkit.ScheduleUtil.isScheduled(
              _this.last_applied_saved_report_index,
              _this.save_util.default_report_is_scheduled,
              _this.save_util.default_index,
              Helpkit.report_filter_data
              );
            if(result.is_scheduled){
              Helpkit.ScheduleUtil.displayScheduleStatus(true,result.tooltip_title);
            } else{
              Helpkit.ScheduleUtil.displayScheduleStatus(false);
            }
            if(invalid_params_found) {
              //update the filter , removing the invalid params done in above loop
              _this.updateSavedReport(false);
            }

        },
        addFiltersToMenu : function(populate_from_locals) {
              var hash = Helpkit.report_filter_data;
              var _this = this;
              var util = Helpkit.TimesheetUtil;
              var invalid_params_found = false;
              var filter_hash = {},columns=[];

              if(populate_from_locals) {
                 filter_hash = Helpkit.locals.local_hash;
              } else {
                 filter_hash = hash[_this.save_util.last_applied_saved_report_index].report_filter.data_hash.report_filters;
              }
              jQuery.each(filter_hash, function(index, filter_row) {
                      var condition = filter_row.condition;
                      if(jQuery.inArray(condition,util.filter_remote) != -1) {

                            var saved_source = filter_row.source;
                            if (filter_row.value.length) {

                              var values = filter_row.value.split(','); // val1,val2,val3 -> [val1,val2,val3]
                              jQuery.each(values,function(idx,val) {
                                var is_saved_param_valid = true;//_FD.checkValidityOfSavedParams(condition,val,saved_source);
                                if(!is_saved_param_valid) {
                                  //source object was spliced in reponse of elastic search itself
                                  values.splice(idx,1);
                                  invalid_params_found = true;
                                }
                              });

                              util.actions.constructReportField(condition,filter_row.value);
                              jQuery('#' + condition).select2(util.getRemoteFilterConfig(condition,true,saved_source));
                              jQuery("#" + condition).select2('val', values);

                            }

                          } else {

                          if (filter_row.value && filter_row.value.length) {
                            var values;
                            if(jQuery.isArray(filter_row.value)) {
                              //For Nested fields , values is already an array
                              values = filter_row.value;
                            } else {
                               values = filter_row.value.split(','); // val1,val2,val3 -> [val1,val2,val3]
                               //Identifying invalid params for neseted fields is not working,because all values are
                               //grouped under same condition, when fixed move the below logic out of the if else.
                               jQuery.each(values,function(idx,val) {
                              var is_saved_param_valid = true;//_FD.checkValidityOfSavedParams(condition,val);
                              if(!is_saved_param_valid) {
                                //source object was spliced in reponse of elastic search itself
                                values.splice(idx,1);
                                invalid_params_found = true;
                              }
                            });
                            }

                            if(jQuery.inArray(condition,util.default_available_filter) != -1){
                              jQuery("#" + condition).select2('val', values);
                            } else{
                              if(jQuery.isArray(filter_row.value)){
                                  util.actions.constructReportField(condition,values);
                                }else{
                                  util.actions.constructReportField(condition,values.toString());
                                }
                            }
                          }
                        }

              });
        },
        setFlag : function(val){
            jQuery('#is_saved_report').val(val);
        },
        checkValidityOfSavedParams : function() {
            return true;
        },
        flushAppliedFilters : function() {
          var self = this;
          var util = Helpkit.TimesheetUtil;
           jQuery("#active-report-filters div.ff_item").map(function() {
                  var condition = this.getAttribute("condition");
                  var container = this.getAttribute("container");
                  var operator  = this.getAttribute("operator");
                  //Removing fields with no values in filters by triggering click.(only for non default fields)
                  if(util.default_available_filter.indexOf(condition) < 0){
                      var active = jQuery('#div_ff_' + condition);
                      if (active.attr('data-type') && active.attr('data-type') === "filter-field") {
                          util.actions.removeField(active);
                      }
                  }
                  else{
                      var active = jQuery('#' + condition);
                      active.select2('val','');
                  }

              });

              //Remove all columns selections
              jQuery("li[data-action=select-column] input").attr('checked',false);
        },
        _constructElasticSearchField : function(condition,initData){

           jQuery('#' + condition).select2('destroy');

           var config = {};
           config.ajax = {
              url: "/search/autocomplete/companies" ,
              dataType: 'json',
              delay: 250,
              data: function (term, page) {
                  return {
                      q: term, // search term
                  };
              },
              results: function (data, params) {
                        var results = [];
                        jQuery.each(data.results, function(index, item){
                              results.push({
                                id: item.id,
                                text: item.value
                              });
                        });
                        return {
                          results: results
                        };
              },
              cache: true
            };
            config.multiple = true ;
            config.minimumInputLength = 2 ;
            config.initSelection = function (element, callback) {
                    if(initData != undefined){
                       callback(initData);
                    }
            };
            jQuery("#" + condition).select2(config);
        },
        init : function(){
           _FD.bindSavedReportEvents();
           _FD.save_util.init();
           _FD.save_util.applyLastCachedReport();
        }
    }
    return _FD;
})();

function showResponseMessage(message) {
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

}
