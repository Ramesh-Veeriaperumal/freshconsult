  jQuery(function(){
  var pciFieldsObject = {
    name: {},
    fieldName: {} 
  };

  var isPciFieldChanged = false;
  var initTry = 0;

  jQuery('.secure_field').each(function(event){
    pciFieldsObject.name[this.name] = true;
    pciFieldsObject.fieldName[jQuery(this).data('field-name')]=true;
  });

  jQuery('.pci-field-container').on('change', '.secure_field', function(event){
    isPciFieldChanged = true;
  });

  jQuery('#portal_ticket_form').submit(function(event) {
    event.stopImmediatePropagation();
    var curr = jQuery(this);
    var formData = new FormData(curr[0]);
    if (isPciFieldChanged) {
      modifyPciFieldsInRequest(formData);
    } else {
      deletePciFieldsFromRequest(formData);
    }
    var url = curr.attr('action');
    var action = curr.attr('method');
    jQuery('#helpdesk_ticket_submit').attr('disabled', true);
    ajaxRequest(action, url, formData)
    .then(callVaultService).fail(reloadWindow);
    return false;
  });

  jQuery('#pci-overwrite').click(function(event){
    isPciFieldChanged = true;
    jQuery(this).attr('disabled', true);
    var parent = jQuery(this).parent();
    var pciField = parent.find('input');
    var clone = pciField.clone().attr({
      'type': 'text',
      'disabled': false
    }).val('');
    pciField.remove();
    parent.append(clone);
  });

  function callVaultService(response) {
    if (response.token) {
      var headers = getHeaders(response.token);
      var data = JSON.stringify(getVaultRequestBody());
      ajaxRequest('put', portal.vault_service.url, data, headers)
      .then(reloadWindow)
      .fail(vaultFailure.bind(this, response));
    } else {
      reloadWindow();
    }
  }

  function reloadWindow() {
    window.location.reload();
  }

  function vaultFailure(response) {
    if (initTry < portal.vault_service.max_try) {
      callVaultService(response);
      initTry++;
    } else {
      reloadWindow();
    }
  }

  function getHeaders(token) {
    return {
      'X-PRODUCT-NAME': portal.vault_service.product_name,
      'X-ACCOUNT-ID': portal.current_account_id,
      'Authorization': token
    };
  }

  function ajaxRequest(action, url, data, headers) {
    return jQuery.ajax({
        type: action,
        url: url,
        headers: headers,
        data: data,
        processData: false,
        contentType: false
    });
  }
  function deletePciFieldsFromRequest(formData) {
    for (var obj in pciFieldsObject.name) {
      formData.delete(obj);
    }
  }
  function modifyPciFieldsInRequest(formData) {
    for (var obj in pciFieldsObject.name) {
      var val = formData.get(obj);
      val && formData.set(obj, Math.random());
    }
  } 
  function getVaultRequestBody() {
    for (var obj in pciFieldsObject.fieldName) {
      pciFieldsObject.fieldName[obj] = jQuery('#'+obj).val();
    }
    return nameMapping(pciFieldsObject.fieldName);
  }
  function nameMapping(obj) {
    var newObj = {};
    for(var key in obj) {
      var splits = key.split('_');
      splits.pop();
      newObj[splits.join('_')] = obj[key];
    }
    return newObj;
  }
});