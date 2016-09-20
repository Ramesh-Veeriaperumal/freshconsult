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
      var customizedData = _customizeData(args.data);
      _populateFields(customizedData, args);
      return;
    }

    _getData(args.url, args.defaultKey, function(data){
      _populateFields(data, args);
    });

  }

  return {
    init: init
  }

  // PRIVATE
  /**
   * [_customizeData description]
   * @param  {[type]} args [description]
   * @return {[type]}      [description]
   */
  function _customizeData(args){
    var fieldMap = {
      agent: "responder_id",
      group: "group_id"
    }, data = {}, newkey;

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

  function _populateFields(data, args){
    var initialData = getInitialData(args['defaultKey']),
        responseData = args.isAjax ? data.conditions : data;
        extendedData = jQuery.extend(initialData, responseData),
        selectedFields = _getKeys(extendedData),
        meta_data = data.meta_data;

    selectedFields.each(function(val, index){

      if(val !== 'spam' && val !== 'deleted'){
        _populateIndividualField(val, extendedData, meta_data);
      }
    });

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
    switch ($wrapperData.domtype) {

      case "nested_field":
        // jQuery("[condition='"+$wrapperData.id+"']").children('select').val(dataArray).trigger('change', ['customTrigger']);
         jQuery("[condition='"+$wrapperData.id+"']").children('select').val(dataArray).trigger('change', ['customTrigger']);
        break;

      case 'dropdown':
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

}());
