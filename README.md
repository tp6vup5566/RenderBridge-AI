# RenderBridge AI

RenderBridge AI is a SketchUp rendering bridge prototype built for a software engineering interview assignment. It is not a commercial rendering engine. The goal is to demonstrate a clean client-server architecture, API integration ability, and a non-blocking async strategy for SketchUp Ruby plugins.

## Architecture

```txt
SketchUp
  |
  | UI::HtmlDialog
  v
SketchUp Ruby Plugin
  |
  | 1. Capture active viewport with view.write_image
  | 2. Encode PNG as Base64
  | 3. Start background HTTP worker
  v
FastAPI Middleware
  |
  | Mock AI render endpoint
  | asyncio.sleep(5)
  v
Mock Render Result
  |
  | JSON response with Base64 image
  v
HtmlDialog Preview
```

The important design choice is that the SketchUp UI is not blocked while waiting for the backend. SketchUp API calls stay on the main thread, while HTTP I/O runs in a Ruby background thread. The main thread uses `UI.start_timer` to poll completed jobs and update the dialog safely.

## Project Structure

```txt
backend/
  app/main.py                  FastAPI mock rendering API
  requirements.txt             Python dependencies

sketchup_plugin/
  renderbridge_ai.rb           SketchUp extension registration file
  renderbridge_ai/main.rb      Plugin logic, viewport capture, async job polling
  renderbridge_ai/ui/index.html
                                HtmlDialog UI

docs/
  ai-collaboration-report.md   AI collaboration report
  ai-collaboration-report.pdf  PDF export for interview submission
```

## Backend Setup

From the repository root:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Health check:

```bash
curl http://127.0.0.1:8000/health
```

Mock render request:

```bash
curl -X POST http://127.0.0.1:8000/api/render \
  -H "Content-Type: application/json" \
  -d '{"prompt":"warm interior render","image_base64":"ZmFrZS1pbWFnZQ=="}'
```

## SketchUp Plugin Setup

1. Start the FastAPI backend on `127.0.0.1:8000`.
2. Copy or symlink the plugin files into the SketchUp Plugins directory.

Example symlink on macOS:

```bash
ln -s "$PWD/sketchup_plugin/renderbridge_ai.rb" \
  "$HOME/Library/Application Support/SketchUp 2024/SketchUp/Plugins/renderbridge_ai.rb"

ln -s "$PWD/sketchup_plugin/renderbridge_ai" \
  "$HOME/Library/Application Support/SketchUp 2024/SketchUp/Plugins/renderbridge_ai"
```

Adjust `SketchUp 2024` if your installed SketchUp version is different.

3. Restart SketchUp.
4. Open `Extensions > RenderBridge AI`.
5. Enter a prompt and click `Render`.

## Core Features

- Registers `RenderBridge AI` under the SketchUp `Extensions` menu.
- Opens a `UI::HtmlDialog` with preview area, prompt input, render button, backend health button, and status feedback.
- Captures the current SketchUp viewport using `view.write_image`.
- Encodes the viewport image as Base64.
- Sends prompt and image data to FastAPI through a background HTTP worker.
- Uses `UI.start_timer` polling to update the dialog without blocking SketchUp.
- Uses a mock FastAPI endpoint with `asyncio.sleep(5)` to simulate cloud rendering latency.

## GitHub Push Commands

This repository is already configured with:

```bash
git remote add origin git@github.com:tp6vup5566/RenderBridge-AI.git
git push -u origin master
```

For future steps:

```bash
git add .
git commit -m "your commit message"
git push
```

## Verification Performed

```bash
ruby -c sketchup_plugin/renderbridge_ai.rb
ruby -c sketchup_plugin/renderbridge_ai/main.rb
python -m compileall backend/app
curl http://127.0.0.1:8000/health
curl -X POST http://127.0.0.1:8000/api/render ...
```

Full SketchUp runtime validation must be done inside SketchUp because `view.write_image` depends on the SketchUp application environment.

## Interview Report

The AI collaboration report is available in:

- `docs/ai-collaboration-report.md`
- `docs/ai-collaboration-report.pdf`
