OmniChannelConfig = YAML.load_file(File.join(Rails.root, 'config', 'omni_channel_routing.yml'))[Rails.env]

OCR_HOST = OmniChannelConfig['ocr_host']
OCR_KEY = OmniChannelConfig['ocr_key']