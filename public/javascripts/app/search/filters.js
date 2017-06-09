window.App = window.App || {};
window.App.FilterOps = window.App.FilterOps || {};

!function($){
  // "use strict";

  App.FilterOps.Filters = {

    locals: {},
    query_hash: {
      term: '',
      filter_params: {}
    },
    filter_remote_url : {
            "agent" : "agents",
            "company" : "companies",
            "tags" : "tags",
            "requesters" : "requesters"
    },
    filter_remote : ["tags","agent","company","requesters"],
    default_available_filter : [ "agent","group","status","priority" ],
    bindSearchFilterEvents: function(context) {
      var _this = this;
      var $body = jQuery('body');

      _this.removeDefaultSortLinks();

      // Opening the filter pane
      $body.on('click'+context.namespace(), '[data-action="open-filter-menu"]',  function(){
        jQuery("#inner").addClass('openedit');
        _this.attachDefaultFilters();
        jQuery(".search-filters-container").show();
        jQuery(this).hide();
      });

      $body.on('keypress.helpdesk_reports keyup.helpdesk_reports keydown.helpdesk_reports', "#created_at,#due_by", function (ev) {
            _this.disableKeyPress(ev);
      });

      $body.on('click' + context.namespace(),'#load-more-with-filters',function(ev){
            ev.preventDefault();
            _this.performFilteredSearch(true,false);
      });

      // Closing the filter pane
      $body.on('click'+context.namespace(), '[data-action="close-filter-menu"]', function(){
        if(jQuery('#inner').hasClass('openedit')){
            jQuery('#inner').removeClass('openedit');
            jQuery('[data-action="open-filter-menu"]').show();
            setTimeout(function(){
               jQuery(".search-filters-container").hide();
            }, 100);
        }
          jQuery('#search_fields_list').hide();
      });

      // Removing the item from add-more menu
      $body.on('click'+context.namespace(), '[data-action="pop-field"]',  function(){
        _this.popFilterField(this);
      });

      // Adding the item back to add-more menu
      $body.on('click'+context.namespace(), '[data-action="remove-field"]',  function(){
        _this.removeFieldFromFilterPane(this);
      });

      // Toggle add-more menu
      $body.on('click'+context.namespace(), '[data-action="add-filter"]', function () {
          _this.toggleFilterListMenu();
      });

      $body.on('click'+context.namespace(), '[data-action="search-submit"]', function () {
        _this.getFilterDisplayData();
        _this.performFilteredSearch(false,false);
        jQuery("span[data-action='close-filter-menu']").click();

      });

      //Datepicker is not losing focus when other element is clicked.so manually trigger click
      $body.on('focus'+context.namespace(), '#due_by,#created_at', function (ev) {
           var source = jQuery(this).attr('id');
           jQuery(".ui-daterangepicker").hide();
      });

      //sort query
      //TODO : Rewrite this method 'removeDefaultSortLinks' is changed.
      $body.on('click' + context.namespace(),'#search-sort-menu li a',function(ev){
        if(SEARCH_RESULTS_PAGE.is_tickets_page){
          jQuery("#search-sort-menu li").removeClass('selected');
          jQuery("#search-sort-menu li .ticksymbol").remove();

          jQuery(this).parent().addClass('selected').prepend('<span class="icon ticksymbol"></span>');
          jQuery("#sorting_dropdown b:first-child").html(jQuery(this).html())
          _this.performFilteredSearch(false,true);  
        }
      })

      _this.generateFiltersMenu();
    },
    removeDefaultSortLinks : function() {
        //TODO : Rewrite the helper method which generates sort dropdown and modify the function
        var $links = jQuery("#search-sort-menu .dropdown-menu a");
        
        $links.prop('href','javascript:void(0)')
        $links.removeAttr("data-loading-classes data-hide-before data-loading data-remote");

        jQuery($links[0]).attr('data-sort-by','relevance');
        jQuery($links[1]).attr('data-sort-by','created_at');
        jQuery($links[2]).attr('data-sort-by','updated_at');
    },
    attachDefaultFilters : function() {
        var default_filters = this.default_available_filter;
        jQuery.each(default_filters,function(idx,field){
            //check for existing field
            var not_added = jQuery("li[data-prop=" + field + "]").length == 0 ? true : false;
            if(!not_added){
              jQuery("li[data-prop=" + field + "]").click();
            } 
        });
    },
    getRemoteFilterConfig : function(condition){
         var _this = this;
         var include_none = false;
         var noneVal = "-None-" ;
         var none_value = -1;

         var config = {
            maximumSelectionSize: 5
        };
        if(condition == "requesters") {
            config.maximumSelectionSize = 3;
            config.formatResult = function(state) {
              return "<div style='font-weight:bold'>" + state.value + "</div><div>" + state.email + "</div>";
            };
            config.formatSelection = function(state) {
              return "<div>" + state.value + "</div>";
            };
            config.escapeMarkup = function(m) { return m; };
        }

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

                      if(condition != 'requesters') {
                        jQuery.each(data.results, function(index, item){
                                results.push({
                                     id: item.id,
                                    text: item.value
                                });    
                        });
                        return {
                            results: results 
                        };    
                      } else {
                          return {
                              results : data.results
                          };
                    }
            },
            cache: false
          };
          config.multiple = true ;
          config.minimumInputLength = 2 ;
        return config;
    },
    // The key for filter param
    retrieveAccessor: function(field) {
      if(field == 'company') {
        return 'company_id';
      } else if(field == 'agent') {
        return 'responder_id';
      } else if(field == 'tags') {
        return 'tags';

      } else if(field == 'group') {
        return 'group_id';
      } else if(field == 'requesters') {
        return 'requester_id'    
      } else {
        return field;
      }
    },
    setFilterData: function () {
        var _this = this;
        this.query_hash.filter_params = {};
        var filter_param = this.query_hash.filter_params;
        
        jQuery("div.ff_item").map(function () {
            var condition = this.getAttribute("condition");
            var container = this.getAttribute("container");
            var value = [];
            var isAjaxSourceSelect = false;

            //Store the search results in localStorage, otherwise cant populate the filter on page refresh
            searchData = [];


            if(jQuery.inArray(condition,_this.filter_remote) != -1){
                isAjaxSourceSelect = true;
            }

            if (container == "nested_field") {
                value = jQuery(this).children('select').find('option:selected').text();
            } else if (container == "multi_select" || container == "select") {
                if(isAjaxSourceSelect){
                    searchData = jQuery(this).find(".filter_item").select2('data');
                    if( condition == 'tags'){
                            var temp = [];
                            jQuery.each(searchData,function(i,el){
                                temp.push(el.text);
                            });
                            value = temp.join();
                    } else {
                        value = jQuery(this).find(".filter_item").select2('val');
                    }
                }else{
                    if(condition.indexOf("ffs") > -1) {
                        value = jQuery(this).find('option:selected').map(function () {
                          return jQuery(this).text();
                        }).get();
                    } else {
                        value = jQuery(this).find('option:selected').map(function () {
                            return this.value;
                        }).get();
                    }
                }
            } else if(container == "check_box") {
                    value = jQuery(this).find('input').is(":checked");
                    filter_param[condition] = value;
            } else if(container == "date_picker") {
                    var date = jQuery(this).find("input").val();
                    if(date != undefined && date != ''){
                        value.push(_this.dateRangeSplit(date));
                    }
            }
            if (value.length && value != '...') {
                filter_param[_this.retrieveAccessor(condition)] = value.toString()
            } 
        });
        
    },
    dateRangeSplit: function (date_selected) {
        var diff = 0;
        var date_range = date_selected.split('-');
        return date_range[0];
    },
    disableKeyPress: function (ev) {
        ev.preventDefault();
        return false;
    },
    // Initialize the date fields
    initializeDateRange: function(field) {
      var _this = this;

      var dateFormat = getDateFormat('mediumDate').toUpperCase();   
      moment.lang('en');
      var date_op = this.getDateRangeDefinition(dateFormat,0);

      var id = field;
      jQuery('#' + field).daterangepicker({
        earliestDate: Date.parse('Today-30'),
        latestDate: Date.parse('Today'),
        presetRanges: [
          {
              text: I18n.t('helpdesk_reports.today'),
              dateStart: date_op.endDate,
              dateEnd: date_op.endDate,
              period : 'today'
          },
          {
              text: I18n.t('helpdesk_reports.yesterday'),
              dateStart: date_op[1],
              dateEnd: date_op[1],
              period : 'yesterday'
          },
          {
              text: I18n.t('helpdesk_reports.last_num_days',{ num: 7 }),
              dateStart: date_op[7],
              dateEnd: date_op.endDate,
          },
          {
              text: I18n.t('helpdesk_reports.last_num_days',{ num: 14 }),
              dateStart: date_op[14],
              dateEnd: date_op.endDate,
          },          
          {
              text: I18n.t('helpdesk_reports.last_num_days',{ num: 30 }),
              dateStart: date_op[30],
              dateEnd: date_op.endDate,
          }
        ],
        presets: {},
        dateFormat: getDateFormat('datepicker'),
        closeOnSelect: true,
        onChange : function(){
          var selected_val = jQuery('#' + field).val().split("-");
          var from_date = selected_val[0];
          _this.query_hash.filter_params[id] = from_date.trim();
        }
      });
    },
    getDateRangeDefinition : function(dateFormat,date_lag){

        var timezone = App.AdvancedSearch.account_time_zone;
        return {
            1:                    moment.tz(new Date(),timezone).subtract(1,'days').format(dateFormat), 
            7:                    moment.tz(new Date(),timezone).subtract((7   + date_lag),"days").format(dateFormat),
            14:                   moment.tz(new Date(),timezone).subtract((14   + date_lag),"days").format(dateFormat),
            30:                   moment.tz(new Date(),timezone).subtract((30  + date_lag),"days").format(dateFormat),
            90:                   moment.tz(new Date(),timezone).subtract((89  + date_lag),"days").format(dateFormat),
            endDate:              moment.tz(new Date(),timezone).subtract(date_lag,"days").format(dateFormat),
            end_date_with_no_lag: moment.tz(new Date(),timezone).format(dateFormat),
            this_week_start:      moment.tz(new Date(),timezone).startOf('isoWeek').format(dateFormat),
            previous_week_start:  moment.tz(new Date(),timezone).subtract(1, 'weeks').startOf('isoWeek').format(dateFormat),
            previous_week_end:    moment.tz(new Date(),timezone).subtract(1, 'weeks').endOf('isoWeek').format(dateFormat),
            this_month_start:     moment.tz(new Date(),timezone).startOf('month').format(dateFormat),
            previous_month_start: moment.tz(new Date(),timezone).subtract(1,'months').startOf('month').format(dateFormat),
            previous_month_end:   moment.tz(new Date(),timezone).subtract(1,'months').endOf('month').format(dateFormat),
            last_3_months:        moment.tz(new Date(),timezone).subtract(date_lag,"days").subtract(2,'months').startOf('month').format(dateFormat),
            last_6_months:        moment.tz(new Date(),timezone).subtract(date_lag,"days").subtract(5,'months').startOf('month').format(dateFormat),
            this_year_start:      moment.tz(new Date(),timezone).startOf('year').format(dateFormat),
        }
    },

    // Show/hide the list of fields
    toggleFilterListMenu: function() {
      var menu = "#search_fields_list";
      if (!jQuery(menu).is(':visible') && jQuery(menu + ' li').length !== 0) {
          jQuery(menu).show();
      } else {
          jQuery(menu).hide();
      }
    },

    // Generate the list of fields that can be added
    generateFiltersMenu: function() {
      var menu_tmpl = '';
      jQuery.map(this.locals.search_fields_hash, function(element, identifier) {
        menu_tmpl = menu_tmpl + JST['app/search/templates/filter_menu_element'](element);
      })
      jQuery("#search_fields_list ul").html(menu_tmpl);
    },

    // Remove field from field list menu
    popFilterField: function(field) {
      var accessor = jQuery(field).data('prop');
      jQuery(field).remove();

      if(jQuery('#search_fields_list ul li').length == 0) {
        jQuery('.search-fields-selector').hide();
        jQuery('#search_fields_list').hide();
      } else {
        jQuery('.search-fields-selector').show();
        // jQuery('#search_fields_list').show();
      }

      this.addFieldToFilterPane(accessor,jQuery(field).data('container'));
    },

    // Add field to field list menu
    pushFilterField: function(accessor) {
      var ele = this.locals.search_fields_hash[accessor];
      var fieldHtml = JST['app/search/templates/filter_menu_element'](ele);
      
      // if(ele.position === 0) {
      //   jQuery('#search_fields_list ul').prepend(field_html);
      // } else {
      //   // Bug: pop 1, 2 elements. Remove 2 elements. Gets added in 2nd position.
      //   jQuery('#search_fields_list ul li').eq(ele.position-1).after(field_html);
      // }
      var liElements = jQuery('#search_fields_list ul li');
      liElements.splice(ele.position, 0, jQuery(fieldHtml)[0]);
      jQuery('#search_fields_list ul').html(liElements);

      if(jQuery('#search_fields_list ul li').length == 0) {
        jQuery('.search-fields-selector').hide();
        jQuery('#search_fields_list').hide();
      } else {
        jQuery('.search-fields-selector').show();
        jQuery('#search_fields_list').show();
      }
      this.sortFilterMenu();
    },

    // Generate field with options in filter menu
    addFieldToFilterPane: function(accessor,dom_type) {
      var _this = this;
      var ele = this.locals.search_fields_hash[accessor];
      if( accessor == "created_at" || accessor == "due_by") {
        var field_html = JST["app/search/templates/date_field"](ele);
        jQuery('#active-search-filters').append(field_html);
        this.initializeDateRange(accessor);
      } else if(dom_type == "nested_field") { 
        
          var tmpl = JST["app/search/templates/nested_field_tmpl"](ele);
          jQuery('#active-search-filters').append(tmpl);
          jQuery('#' + ele.field_id + '_category').nested_select_tag({
              initValues: _this.nestedFieldInitValues(accessor),
              default_option: "<option value=''>...</option>",
              data_tree: ele.options,
              subcategory_id: ele.field_id + '_sub_category',
              item_id: ele.field_id + '_item_sub_category'
          });
      } else if(dom_type == "check_box") {
          var tmpl = JST["app/search/templates/checkbox_field_tmpl"](ele);
          jQuery('#active-search-filters').append(tmpl);
      }
      else {
        var field_html = JST["app/search/templates/multi_select"](ele);
        jQuery('#active-search-filters').append(field_html);
        var config = { maximumSelectionSize : 5};
        if(jQuery.inArray(accessor,this.filter_remote) != -1){
            config = this.getRemoteFilterConfig(accessor);
        }
        jQuery('#'+accessor+'.filter_item').select2(config);
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
    // Remove field with options from filter menu
    removeFieldFromFilterPane: function(field) {
      var parentField = jQuery(field).parents('.filter-field');
      var accessor = parentField.data('prop');
      parentField.remove();

      this.pushFilterField(accessor);
    },
    sortFilterMenu: function () {
        var list = jQuery("[data-action='pop-field']");
        var listItems = list.sort(function (a, b) {
            return (jQuery(b).data('position')) < (jQuery(a).data('position')) ? 1 : -1;
        }).appendTo('#search_fields_list ul');
    },
    getFilterDisplayData : function(){
       var _this = this;
       _this.locals.select_hash = [];
       
       jQuery(".search-fields-widget,div.ff_item").map(function() {
            var item = this;
            var property = item.getAttribute("data-prop");
            var data_label = item.getAttribute("data-label");
            var container = item.getAttribute("container");
            var value = [];
            //select
            if (container == "nested_field") {
                value = jQuery(item).children('select').find('option:selected').text();
            } else if(container == "check_box") {
                value = [jQuery(item).find("input").is(':checked')];
            } else if(container == "date_picker") {
                var date = jQuery(item).find("input").val();
                if(date != undefined && date != ''){
                    value.push(date);
                }
            } else {
                if(jQuery.inArray(property,_this.filter_remote) != -1) {
                  var data = jQuery(item).find(".select2-container").select2('data');
                  if(data != undefined && data.length > 0){
                      data.map(function(val,i){
                          if(property == "requesters") {
                             value.push(val.value);
                          } else {
                             value.push(val.text);
                          }
                      });
                  }
              } else {
                  value = jQuery(item).find('option:selected').map(function () {
                      return jQuery(this).text();
                  }).get();
              }
  
            }
            
            if ((data_label !== null) && value && value.length && ((container !== "nested_field") || ((container === "nested_field") && (value !== "...")))){
                var values = (typeof value == "string") ? value.toString() : value.join(', ');
                _this.locals.select_hash.push({
                    name: data_label,
                    value: values
                });
            }
       });
       _this.setFilterDisplayData();
    },
    setFilterDisplayData: function () {
        jQuery('.search-filter-pane').addClass('hide');
        if(this.locals.select_hash.length > 0) { // show only if you have any filter values
            jQuery('.search-filter-pane').removeClass('hide');
        }
      var tmpl = JST["app/search/templates/filter_data_template"]({ 
          data: this.locals.select_hash 
      });
      jQuery("#filter_text").html(tmpl);
    },
    // Make ajax request for search
    performFilteredSearch: function(is_load_more,is_sort_query) {
      
      var _this = this;
      _this.query_hash.term = jQuery('.search-input').val();
      _this.setFilterData();

      //if(!is_sort_query){
      jQuery('.loading-box').show();  
      //}
      var next_page = is_load_more ? SEARCH_RESULTS_PAGE.data.current_page + 1 : SEARCH_RESULTS_PAGE.data.current_page ;
      var endpoint = '';
      if(is_sort_query) {
        endpoint = '/search/tickets?page=' + next_page + '&search_sort=' + jQuery("#search-sort-menu li.selected a").attr('data-sort-by')  ;
      } else {
        endpoint = '/search/tickets?page=' + next_page;
      }
      jQuery.ajax({
        url: endpoint ,
        type: 'POST',
        dataType: 'json',
        contentType: 'application/json',
        data: Browser.stringify(this.query_hash),
        timeout: 120000,
        success: function (data) {
          jQuery('.loading-box').hide();
          
          SEARCH_RESULTS_PAGE.data = data;
          window.search_page.renderFilterResults(is_load_more);
          jQuery(".big-info").remove();
          if(data.results.length == 0) {
            // TODO: i18n gem value
            jQuery(".pagearea").append('<div class="big-info"><div class="no-info-text">No matching results for <b>' + _this.query_hash.term + '</b></div></div>');
          } 
        },
        error: function (data) {
          jQuery('.loading-box').hide();
        }
      });
    }
  } 

}(window.jQuery);
