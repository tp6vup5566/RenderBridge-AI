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
      register_callbacks(html_dialog)
      html_dialog
    end

    def register_callbacks(html_dialog)
      html_dialog.add_action_callback('dialog_ready') do |action_context|
        action_context.execute_script(
          "window.RenderBridge.setStatus('Ready. Enter a prompt and click Render.');"
        )
      end

      html_dialog.add_action_callback('render_requested') do |action_context, prompt|
        cleaned_prompt = prompt.to_s.strip

        if cleaned_prompt.empty?
          action_context.execute_script(
            "window.RenderBridge.setStatus('Please enter a prompt before rendering.', 'error');"
          )
          next
        end

        action_context.execute_script(
          "window.RenderBridge.setStatus(#{js_string("Ruby received prompt: #{cleaned_prompt}")});"
        )
      end

      html_dialog.add_action_callback('open_backend_health') do |action_context|
        action_context.execute_script(
          "window.RenderBridge.setStatus('Backend health check will be connected in Step 4.');"
        )
      end
    end

    def js_string(value)
      value.to_s.dump
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
