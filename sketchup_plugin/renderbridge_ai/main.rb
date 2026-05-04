require 'sketchup.rb'

module RenderBridgeAI
  PLUGIN_ROOT = File.expand_path(__dir__).freeze
  UI_PATH = File.join(PLUGIN_ROOT, 'ui', 'index.html').freeze

  class << self
    def show_dialog
      dialog.show
      dialog.bring_to_front
    end

    def dialog
      @dialog ||= build_dialog
    end

    private

    def build_dialog
      html_dialog = UI::HtmlDialog.new(
        dialog_title: 'RenderBridge AI',
        preferences_key: 'com.chensin.renderbridge_ai',
        scrollable: true,
        resizable: true,
        width: 420,
        height: 560,
        min_width: 360,
        min_height: 420,
        style: UI::HtmlDialog::STYLE_DIALOG
      )

      html_dialog.set_file(UI_PATH)
      html_dialog
    end

    def register_menu
      UI.menu('Extensions').add_item('RenderBridge AI') do
        show_dialog
      end
    end
  end

  unless file_loaded?(__FILE__)
    register_menu
    file_loaded(__FILE__)
  end
end
