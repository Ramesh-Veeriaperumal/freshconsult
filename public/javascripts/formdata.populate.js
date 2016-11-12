/**
  *
  * Simple factory function helps to populate form data through
  * Ajax
  *
  * Dependency: jQuery
  *
  * Params : parentWrapper should be an ID
  * 				 childWrapper should be class
  *
  */

var PopulateFormData = PopulateFormData ||  (function(){

  /**
   * id - form id
   * endpoint  - url from which data has to be fetched
   */

  function init(args){
    var args = args || {};
    // Populate the group and agent select2
     PopulateData.fromStore("#group_id", 'group',true);
     PopulateData.fromStore("#responder_id", 'agent',true);
    // check is ajax required
    if(!args.isAjax){
      _populateFields(args.data, args);
      _resetFilterDataHash();
      return;
    }
    _getData(args.url, args.defaultKey, function(data){
      _populateFields(data, args);
      _resetFilterDataHash(args.defaultKey);
    });

  }

  return {
    init: init
  }

  // PRIVATE

  function _resetFilterDataHash(defaultKey){
    var special_case_views = ['deleted','spam','monitored_by'];
    if(defaultKey && special_case_views.indexOf(defaultKey) !=-1) return;
    getFilterData();
    jQuery("#FilterOptions input[name=data_hash]").val(query_hash.toJSON());
  }
  /**
   * [_customizeData description]
   * @param  {[type]} args [description]
   * @return {[type]}      [description]
   */

  function _customizeData(args, fieldMap){
    var data = {}, newkey;
    for(var key in args){
      newkey = (fieldMap[key]) ? fieldMap[key] : key
      data[newkey] = args[key];
    }
    return data;
  }

  // Store result of filter data // Memoization
  function _cacheFilter(){
    var cacheObj = {};
  }

  function _getData(endpoint, params, cb){
    var paramKey = _findParamType(params), data = {};
    data[paramKey] = params;
    return jQuery.getJSON(endpoint, data, cb)
  }

  function _findParamType(key){
    return typeof parseInt(key) === "number" ? "filter_key" : "filter_name"
  }

  function _getKeys(data){
    return Object.keys(data)
  }

  function _setCustomFilterModes(agent, group){
    if(agent >= 0){
      jQuery("#agentSort").parent().data("fromFilters", true);
      jQuery(".shared_sort_menu .agent_mode[mode='"+agent+"']").trigger('click',['customTrigger']);
    }

    if(group >= 0){
      jQuery("#groupSort").parent().data("fromFilters", true);
      jQuery(".shared_sort_menu .group_mode[mode='"+group+"']").trigger('click',['customTrigger']);
    }
  }

  function _populateFields(data, args){
    var initialData, responseData, extendedData, selectedFields, meta_data;
    responseData = args.isAjax ? data.conditions : _customizeData(data, args.fieldMap);
    if(args.sharedOwnershipFlag){
       _setCustomFilterModes(data.agent_mode || 0, data.group_mode || 0)
    }
    initialData = getInitialData(args['defaultKey']);
    extendedData = jQuery.extend(initialData, responseData);
    selectedFields = _getKeys(extendedData);
    meta_data = data.meta_data;
    initialData.defaultDateRange = args.defaultDateRange;
    selectedFields.each(function(val, index){
      if(val !== 'spam' && val !== 'deleted'){
        _populateIndividualField(val, extendedData, meta_data);
      }
    });
    jQuery(".sloading.filter-loading").hide();
  }

  function getInitialData(view_name){
    var initialObj = {}, key;
    jQuery(".ff_item").each(function(){
      key = jQuery(this).attr('condition');
      initialObj[key] = '';
      if(key == 'created_at'){
        initialObj[key] = (view_name == 'all_tickets') ? "last_month" : "any_time";
      }
    });
    return initialObj;
  }

  function _populateIndividualField(val, data, meta_data){
    var $wrapper = jQuery("[condition='"+val+"']");
    var $wrapperData = $wrapper.data(),
        dataArray = data[val].toString().split(",");
    if($wrapperData){
      switch ($wrapperData.domtype) {

        case "nested_field":
          // jQuery("[condition='"+$wrapperData.id+"']").children('select').val(dataArray).trigger('change', ['customTrigger']);
           jQuery("[condition='"+$wrapperData.id+"']").children('select').val(dataArray).trigger('change', ['customTrigger']);
          break;

        case 'dropdown':
            jQuery("[condition='"+$wrapperData.id+"']").find('input').prop('checked', false);
            dataArray.each(function(val, index){
                jQuery("[condition='"+$wrapperData.id+"']").find('input[value="'+val+'"]').prop('checked', true);
            });
          break;
        case 'multi_select':
          if(jQuery("#"+val).length == 0){
            jQuery("[condition='"+$wrapperData.id+"']").children('select').val(dataArray).trigger('change.select2');
          }
          else{
            jQuery("#"+val).val(dataArray).trigger('change.select2');
          }
          break;
        case 'association_type':
          jQuery("[condition='"+$wrapperData.id+"']").children('select').val(dataArray).trigger('change.select2');
          break;
        case 'single_select':
          var dateRange = dataArray[0].split("-");
          if(dateRange.length==2){
            jQuery("#created_date_range").val(dataArray);
            jQuery("#"+val).data('selectedValue',dataArray).val('set_date').trigger('change.select2');
            jQuery('#div_ff_created_date_range').show();
          }
          else{
            dateRange = data.defaultDateRange.split("-");
            jQuery("#"+val).val(dataArray).trigger('change.select2');
            jQuery('#div_ff_created_date_range').hide();
            jQuery('#created_date_range').val('');
          }
          try{
            var datePicker = jQuery("#created_date_range").data('bootstrapdaterangepicker');
            datePicker.setStartDate(dateRange[0]);
            datePicker.setEndDate(dateRange[1]);
          }
          catch(e){
            console.log(e)
          }
          
          break;
        case 'requester':
        case 'customers':
        case 'tags':
          if(meta_data && meta_data[$wrapperData.id]){
            jQuery("#"+$wrapperData.domtype+"_filter").select2('data', meta_data[$wrapperData.id]);
          }
          else{
            jQuery("#"+$wrapperData.domtype+"_filter").select2('data','');
          }
          break;
        default:
            jQuery("#"+val).val(dataArray).trigger('change.select2');

      }
    }
    
  }

}());
