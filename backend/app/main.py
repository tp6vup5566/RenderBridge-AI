import asyncio
from datetime import datetime, timezone
from typing import Annotated

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field


app = FastAPI(
    title="RenderBridge AI Mock Middleware",
    description="A lightweight mock rendering API for the SketchUp RenderBridge AI plugin.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


class RenderRequest(BaseModel):
    prompt: Annotated[str, Field(min_length=1, max_length=500)]
    image_base64: Annotated[str, Field(min_length=1)]


class RenderResponse(BaseModel):
    status: str
    prompt: str
    render_id: str
    message: str
    result_image_base64: str
    created_at: str


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/render", response_model=RenderResponse)
async def render(request: RenderRequest) -> RenderResponse:
    image_base64 = request.image_base64.strip()
    prompt = request.prompt.strip()

    if not prompt:
        raise HTTPException(status_code=422, detail="Prompt cannot be blank.")

    if "," in image_base64:
        image_base64 = image_base64.split(",", 1)[1]

    await asyncio.sleep(5)

    created_at = datetime.now(timezone.utc).isoformat()
    render_id = f"mock-{int(datetime.now(timezone.utc).timestamp())}"

    return RenderResponse(
        status="completed",
        prompt=prompt,
        render_id=render_id,
        message="Mock render completed. Replace this endpoint with a real rendering provider later.",
        result_image_base64=image_base64,
        created_at=created_at,
    )
