require 'sketchup.rb'
require 'extensions.rb'

module RenderBridgeAI
  EXTENSION_NAME = 'RenderBridge AI'.freeze
  EXTENSION_VERSION = '0.1.0'.freeze

  unless file_loaded?(__FILE__)
    extension = SketchupExtension.new(
      EXTENSION_NAME,
      'renderbridge_ai/main'
    )

    extension.creator = 'Chen Sin'
    extension.version = EXTENSION_VERSION
    extension.description = 'A SketchUp client for sending viewport captures to a FastAPI mock rendering bridge.'
    extension.copyright = '2026 Chen Sin'

    Sketchup.register_extension(extension, true)
    file_loaded(__FILE__)
  end
end
