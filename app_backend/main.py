# main.py
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os, base64, httpx, hashlib

app = FastAPI(title="PET-I Backend (Full Inference Flow)")

# ======== 환경 변수 =========
RUNPOD_ENDPOINT_ID = os.getenv("RUNPOD_ENDPOINT_ID", "")
RUNPOD_API_KEY = os.getenv("RUNPOD_API_KEY", "")
RUNPOD_URL = f"https://api.runpod.ai/v2/{RUNPOD_ENDPOINT_ID}/runsync" if RUNPOD_ENDPOINT_ID else ""

# ======== 설정 =========
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/jpg", "image/webp", "application/octet-stream"}
MAX_FILE_MB = 15
MAX_FILE_BYTES = MAX_FILE_MB * 1024 * 1024

# ======== CORS =========
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실제 배포 시 프론트 도메인으로 변경 권장
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ======== Health Check =========
@app.get("/health")
async def health():
    ok = bool(RUNPOD_URL and RUNPOD_API_KEY)
    return {
        "status": "ok" if ok else "misconfigured",
        "runpod_endpoint_id": RUNPOD_ENDPOINT_ID or None
    }

# ======== 예측 (이미지 업로드 → Runpod 호출) =========
@app.post("/predict")
async def predict(
    image: UploadFile = File(...),
    note: str = Form("")
):
    # 1️ 파일 검증
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

    # 2️ Base64 인코딩
    b64_img = base64.b64encode(content).decode("utf-8")

    # 3️ Runpod에 보낼 프롬프트 & 설정 (고정값)
    PROMPT = """[diagnosis_report]
당신은 반려동물의 질환 진단을 위한 수의사입니다.
사진을 보고 반려동물의 안구 질환을 진단하여 진단 리포트를 작성하세요.
‘# 진단명’, ‘## 증상’ 헤더를 포함하세요.
형식은 마크다운 형식으로 작성해주세요."""
    payload = {
        "input": {
            "prompt": PROMPT,
            "images": [b64_img],
            "gen": {
                "max_new_tokens": 256,
                "temperature": 0.2
            },
            "model" : "diag",
            "use_lora": True
        }
    }

    # 4️ Runpod 호출
    try:
        async with httpx.AsyncClient(timeout=180) as client:
            response = await client.post(
                RUNPOD_URL,
                json=payload,
                headers={"Authorization": f"Bearer {RUNPOD_API_KEY}"}
            )
        result = response.json()

        # Runpod 응답에서 핵심 정보 추출
        raw_model_output = (
            result.get("output")
            or result.get("response")
            or result.get("result")
            or result
        )

        if isinstance(raw_model_output, dict):
            model_output = raw_model_output.get("output", "")
        else:
            model_output = str(raw_model_output)

        # 이미지 해시 생성 (응답 추적용)
        image_hash = hashlib.sha256(content).hexdigest()[:16]

        return {
            "status": "ok" if response.status_code == 200 else "runpod_error",
            "upstream_status": response.status_code,
            "data": {
                "model_output": model_output,
                #"model_name": "runpod-handler",
                #"model_version": "v1",
                "image_hash": image_hash,
                #"echo_note": note
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
    

from pydantic import BaseModel

class ChatRequest(BaseModel):
    messages: str

@app.post("/chat")
async def chat(req: ChatRequest):
    payload = {
        "input": {
            "prompt": req.message,
            "images": [],   # 필요하면 나중에 이미지도 붙일 수 있음
            "gen": {
                "max_new_tokens": 512,
                "temperature": 0.2,
            },
            "mode": "chat",     # 챗봇 모드 → 기본적으로 LoRA OFF
            "use_lora": False   # 확실히 끄고 싶으면 명시
        }
    }

    async with httpx.AsyncClient(timeout=180) as client:
        res = await client.post(
            RUNPOD_URL,
            json=payload,
            headers={"Authorization": f"Bearer {RUNPOD_API_KEY}"}
        )

    data = res.json()
    text = data.get("output") or data.get("data") or data
    # text 파싱해서 Flutter chat_page 로 넘기면 됨
    return {"answer": text}

@app.get("/")
def root():
    return {"msg": "FASTAPI OK"}