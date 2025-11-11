# main.py
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os
import base64
import httpx
import hashlib

# -----------------------------
# 환경 설정
# -----------------------------
app = FastAPI(title="PET-I Backend (Runpod Integration)")

# 환경 변수에서 Runpod 엔드포인트 설정
RUNPOD_ENDPOINT_ID = os.getenv("RUNPOD_ENDPOINT_ID", "")
RUNPOD_API_KEY = os.getenv("RUNPOD_API_KEY", "")
RUNPOD_URL = f"https://api.runpod.ai/v2/{RUNPOD_ENDPOINT_ID}/runsync" if RUNPOD_ENDPOINT_ID else ""

# 허용된 이미지 타입
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/webp", "image/jpg"}
MAX_FILE_MB = 15
MAX_FILE_BYTES = MAX_FILE_MB * 1024 * 1024

# -----------------------------
# CORS 허용 (테스트용)
# -----------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실제 서비스에서는 프론트 도메인으로 제한 권장
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# -----------------------------
# Health check
# -----------------------------
@app.get("/health")
async def health():
    ok = bool(RUNPOD_URL and RUNPOD_API_KEY)
    return {
        "status": "ok" if ok else "misconfigured",
        "runpod_endpoint_id": RUNPOD_ENDPOINT_ID or None
    }

# -----------------------------
# 이미지 예측 엔드포인트
# -----------------------------
@app.post("/predict")
async def predict(
    image: UploadFile = File(...),
    prompt: str = Form("You are a veterinary VLM diagnosing canine eye diseases. Respond in JSON."),
    max_new_tokens: int = Form(256),
    temperature: float = Form(0.2),
    note: str = Form("")
):
    # 1️⃣ 파일 검증
    if image.content_type not in ALLOWED_TYPES:
        return JSONResponse(status_code=415, content={
            "status": "error",
            "code": "BAD_INPUT",
            "message": f"Only {', '.join(ALLOWED_TYPES)} supported"
        })

    content = await image.read()
    if len(content) > MAX_FILE_BYTES:
        return JSONResponse(status_code=413, content={
            "status": "error",
            "code": "FILE_TOO_LARGE",
            "message": f"File exceeds {MAX_FILE_MB}MB limit"
        })

    # 2️⃣ Base64 인코딩
    b64_img = base64.b64encode(content).decode("utf-8")

    # 3️⃣ Runpod payload 구성
    payload = {
        "input": {
            "prompt": prompt,
            "images": [b64_img],
            "gen": {
                "max_new_tokens": max_new_tokens,
                "temperature": temperature
            }
        }
    }

    # 4️⃣ Runpod 호출
    try:
        async with httpx.AsyncClient(timeout=120) as client:
            rp = await client.post(
                RUNPOD_URL,
                json=payload,
                headers={"Authorization": f"Bearer {RUNPOD_API_KEY}"}
            )

        data = rp.json()
        model_output = (
            data.get("output")
            or data.get("response")
            or data.get("result")
            or data
        )

        image_hash = hashlib.sha256(content).hexdigest()[:16]

        return {
            "status": "ok" if rp.status_code == 200 else "runpod_error",
            "upstream_status": rp.status_code,
            "data": {
                "model_output": model_output,
                "model_name": "runpod-handler",
                "model_version": "v1",
                "image_hash": image_hash,
                "echo_note": note
            }
        }

    except httpx.ReadTimeout:
        return JSONResponse(status_code=504, content={
            "status": "error",
            "code": "RUNPOD_TIMEOUT",
            "message": "Runpod request timed out."
        })
    except Exception as e:
        return JSONResponse(status_code=502, content={
            "status": "error",
            "code": "RUNPOD_CALL_FAILED",
            "message": f"{type(e).__name__}: {e}"
        })
