require 'sketchup.rb'
require 'base64'
require 'json'
require 'net/http'
require 'securerandom'
require 'thread'
require 'tmpdir'
require 'uri'

module RenderBridgeAI
  PLUGIN_ROOT = File.expand_path(__dir__).freeze
  UI_PATH = File.join(PLUGIN_ROOT, 'ui', 'index.html').freeze
  BACKEND_BASE_URL = 'http://127.0.0.1:8000'.freeze

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
      html_dialog.add_action_callback('dialog_ready') do |_action_context|
        execute_script(
          html_dialog,
          "window.RenderBridge.setStatus('Ready. Enter a prompt and click Render.');"
        )
      end

      html_dialog.add_action_callback('render_requested') do |_action_context, prompt|
        cleaned_prompt = prompt.to_s.strip

        if cleaned_prompt.empty?
          execute_script(
            html_dialog,
            "window.RenderBridge.setStatus('Please enter a prompt before rendering.', 'error');"
          )
          next
        end

        begin
          image_base64 = capture_viewport_base64
          job_id = enqueue_render_request(cleaned_prompt, image_base64)

          execute_script(
            html_dialog,
            "window.RenderBridge.setLoading(#{js_string("Rendering in background... Job #{job_id}")});"
          )
          start_polling(html_dialog)
        rescue StandardError => e
          execute_script(
            html_dialog,
            "window.RenderBridge.setStatus(#{js_string("Capture failed: #{e.message}")}, 'error');"
          )
        end
      end

      html_dialog.add_action_callback('open_backend_health') do |_action_context|
        job_id = enqueue_health_request
        execute_script(
          html_dialog,
          "window.RenderBridge.setLoading(#{js_string("Checking backend... Job #{job_id}")});"
        )
        start_polling(html_dialog)
      end
    end

    def capture_viewport_base64
      model = Sketchup.active_model
      raise 'No active SketchUp model.' unless model

      view = model.active_view
      temp_path = File.join(Dir.tmpdir, "renderbridge-ai-#{SecureRandom.hex(8)}.png")
      written = view.write_image(temp_path)
      raise 'SketchUp could not write the viewport image.' unless written && File.exist?(temp_path)

      Base64.strict_encode64(File.binread(temp_path))
    ensure
      File.delete(temp_path) if temp_path && File.exist?(temp_path)
    end

    def enqueue_render_request(prompt, image_base64)
      job_id = SecureRandom.hex(6)
      add_job(job_id, type: :render, status: :pending)

      # Keep SketchUp API calls on the main thread. This worker only performs HTTP I/O.
      Thread.new do
        post_json(
          "#{BACKEND_BASE_URL}/api/render",
          prompt: prompt,
          image_base64: image_base64
        ) do |result|
          finish_job(job_id, result)
        end
      end

      job_id
    end

    def enqueue_health_request
      job_id = SecureRandom.hex(6)
      add_job(job_id, type: :health, status: :pending)

      # Health checks use the same non-blocking path as render requests.
      Thread.new do
        get_json("#{BACKEND_BASE_URL}/health") do |result|
          finish_job(job_id, result)
        end
      end

      job_id
    end

    def post_json(url, payload)
      uri = URI(url)
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(payload)

      response = request_http(uri, request)
      yield parse_response(response)
    rescue StandardError => e
      yield(error: e.message)
    end

    def get_json(url)
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      response = request_http(uri, request)
      yield parse_response(response)
    rescue StandardError => e
      yield(error: e.message)
    end

    def request_http(uri, request)
      Net::HTTP.start(
        uri.hostname,
        uri.port,
        read_timeout: 20,
        open_timeout: 3,
        use_ssl: uri.scheme == 'https'
      ) do |http|
        http.request(request)
      end
    end

    def parse_response(response)
      body = JSON.parse(response.body)
      return body if response.is_a?(Net::HTTPSuccess)

      { error: "HTTP #{response.code}: #{body}" }
    rescue JSON::ParserError
      { error: "HTTP #{response.code}: #{response.body}" }
    end

    def add_job(job_id, data)
      job_mutex.synchronize do
        jobs[job_id] = data
      end
    end

    def finish_job(job_id, result)
      job_mutex.synchronize do
        job = jobs[job_id]
        next unless job

        job[:status] = result[:error] || result['error'] ? :error : :done
        job[:result] = result
      end
    end

    def start_polling(html_dialog)
      return if @polling

      @polling = true

      UI.start_timer(0.25, true) do
        completed_jobs = collect_completed_jobs

        completed_jobs.each do |job|
          update_dialog_for_job(html_dialog, job)
        end

        @polling = pending_jobs?
        @polling
      end
    end

    def collect_completed_jobs
      job_mutex.synchronize do
        finished_ids = jobs.select { |_id, job| job[:status] != :pending }.keys
        finished_ids.map { |id| jobs.delete(id).merge(id: id) }
      end
    end

    def pending_jobs?
      job_mutex.synchronize do
        jobs.any? { |_id, job| job[:status] == :pending }
      end
    end

    def update_dialog_for_job(html_dialog, job)
      result = job[:result] || {}

      if job[:status] == :error
        message = result[:error] || result['error'] || 'Unknown backend error.'
        execute_script(
          html_dialog,
          "window.RenderBridge.setStatus(#{js_string(message)}, 'error');"
        )
        return
      end

      case job[:type]
      when :render
        execute_script(
          html_dialog,
          "window.RenderBridge.setRenderResult(#{JSON.generate(result)});"
        )
      when :health
        execute_script(
          html_dialog,
          "window.RenderBridge.setStatus(#{js_string("Backend status: #{result['status'] || 'unknown'}")});"
        )
      end
    end

    def jobs
      @jobs ||= {}
    end

    def job_mutex
      @job_mutex ||= Mutex.new
    end

    def execute_script(html_dialog, script)
      html_dialog.execute_script(script)
    rescue StandardError => e
      puts "RenderBridge AI dialog update failed: #{e.message}"
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
