/*
  HACK:
  Loading recaptcha in iframe to avoid prototype conflict with google recaptcha JS
  * This js create's messagechannel to get messages from the recaptcha frame,
  * It gets the captcha token from iframe and sets the value to the rendered form
  * It resizes the iframe based on the message
  * Makes iframe resizable if "MutationObserver" not available
*/


// JS for parent frame
window.onload = function() {
  // create channel
  var portalRecaptcha = {}
  portalRecaptcha.channel = new MessageChannel()
  portalRecaptcha.channel.port1.onmessage = handleMessageFromChild

  // send port to iframe
  var $recaptchaIframe = document.getElementById('recaptcha-frame')
  if (!$recaptchaIframe) {
    return true;
  }

  $recaptchaIframe.contentWindow.postMessage('init', window.location.origin, [portalRecaptcha.channel.port2]);

  if (!("MutationObserver" in window)) {
    $recaptchaIframe.style.resize="both" // make iframe resizable
  }

  var recaptchaFrameSize = {
    minimize: {
      height: "100px",
      width: "320px"
    },
    expand: {
      height: "500px",
      width: "350px"
    }
  }

  // onmessage callback
  function handleMessageFromChild(event) {
    var data = event.data
    switch (data.type) {
      case 'token':
        // get token from parent and inject to form
        var $recaptchaResponseFieldId = 'g-recaptcha-response'
        var $recaptchaResponseField = document.getElementById($recaptchaResponseFieldId)
        if (!$recaptchaResponseField) { // if no captcha field create one
          var form = jQuery('#recaptcha-frame').closest('form')
          $recaptchaResponseField = document.createElement('input')
          $recaptchaResponseField.type = "hidden"
          $recaptchaResponseField.name = $recaptchaResponseFieldId
          $recaptchaResponseField.id = $recaptchaResponseFieldId
          form.append($recaptchaResponseField)
        }

        $recaptchaResponseField.value = data.token // set token
        break;

      // resizing iframe based on child messages
      case 'expand':
        $recaptchaIframe.height = recaptchaFrameSize.expand.height
        $recaptchaIframe.width = recaptchaFrameSize.expand.width
        $recaptchaIframe.scrollIntoView()
        break;

      case 'minimize':
        $recaptchaIframe.height = recaptchaFrameSize.minimize.height
        $recaptchaIframe.width = recaptchaFrameSize.minimize.width
        break;

      default:
        break;
    }
  }
}
