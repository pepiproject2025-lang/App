# main.py
from fastapi import FastAPI, File, UploadFile, Form
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import os, base64, httpx, hashlib
import asyncio
from dotenv import load_dotenv
load_dotenv()


app = FastAPI(title="PET-I Backend (Full Inference Flow)")

# ======== 환경 변수 =========
RUNPOD_ENDPOINT_ID = os.getenv("RUNPOD_ENDPOINT_ID", "")
RUNPOD_API_KEY = os.getenv("RUNPOD_API_KEY", "")
RUNPOD_URL = f"https://api.runpod.ai/v2/{RUNPOD_ENDPOINT_ID}/runsync" if RUNPOD_ENDPOINT_ID else ""

# ======== 설정 =========
ALLOWED_TYPES = {"image/jpeg", "image/png", "image/jpg", "image/webp", "application/octet-stream"}
MAX_FILE_MB = 15
MAX_FILE_BYTES = MAX_FILE_MB * 1024 * 1024
print("RUNPOD_URL =", RUNPOD_URL)

# ======== CORS =========
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실제 배포 시 프론트 도메인으로 변경 권장
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


async def wait_for_runpod_result(job_id: str, headers: dict):
    status_url = f"https://api.runpod.ai/v2/{RUNPOD_ENDPOINT_ID}/status/{job_id}"
    
    while True:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.get(status_url, headers=headers)
        print(f"DEBUG: RunPod response: {response.json()}")
        data = response.json()
        status = data.get("status")
        
        if status == "COMPLETED":
            return data.get("output")
        elif status == "FAILED":
            raise Exception(f"Runpod Job Failed: {data}")
            
        # 아직 진행 중이면 1초 대기 후 재시도
        print(f"Job {job_id} is {status}... waiting.")
        await asyncio.sleep(1)


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
                "diagnosis": raw_model_output.get("diagnosis") if isinstance(raw_model_output, dict) else None,
                "case_id": raw_model_output.get("case_id") if isinstance(raw_model_output, dict) else None,
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
    message: str
    case_id: str | None = None
    image: str | None = None  # Base64 encoded image string

@app.post("/chat")
async def chat(req: ChatRequest):
    # 이미지가 있으면 리스트에 추가
    images_list = [req.image] if req.image else []
    
    payload = {
        "input": {
            "prompt": req.message,
            "case_id": req.case_id,
            "images": images_list,
            "gen": {
                "max_new_tokens": 512,
                "temperature": 0.2,
            },
            "mode": "chat",     # 챗봇 모드 → 기본적으로 LoRA OFF
            "use_lora": False   # 확실히 끄고 싶으면 명시
        }
    }

    headers = {"Authorization": f"Bearer {RUNPOD_API_KEY}"}
    print(f"DEBUG: Sending payload to RunPod: {payload}")
    async with httpx.AsyncClient(timeout=180) as client:
        res = await client.post(
            RUNPOD_URL,
            json=payload,
            headers=headers
        )

    data = res.json()
    if data.get("status") in ["IN_QUEUE", "IN_PROGRESS"]:
        job_id = data.get("id")
        # 폴링 함수 호출하여 완료될 때까지 대기
        final_output = await wait_for_runpod_result(job_id, headers)
        text = final_output
        
    # 2. 바로 결과가 왔다면 (COMPLETED 혹은 결과 json 직접 반환)
    # 2. 바로 결과가 왔다면 (COMPLETED 혹은 결과 json 직접 반환)
    else:
        # 에러 상태 체크
        if data.get("status") == "FAILED":
            print(f"DEBUG: RunPod Job Failed immediately: {data}")
            return {"answer": "죄송합니다. 일시적인 오류로 답변을 생성할 수 없습니다. 잠시 후 다시 시도해주세요."}
            
        text = data.get("output") or data.get("data") or data

    # 결과 포맷팅 (output 필드 추출 등 필요 시 추가 처리)
    if isinstance(text, dict):
        if "output" in text:
            text = text["output"]
        elif "error" in text: # 에러 객체가 포함된 경우
             print(f"DEBUG: RunPod returned error object: {text}")
             return {"answer": "죄송합니다. 답변 생성 중 문제가 발생했습니다. 다시 질문해 주시겠어요?"}

    # 만약 text가 여전히 dict라면 (위에서 처리가 안 된 경우) 문자열로 변환하거나 에러 메시지
    if isinstance(text, dict):
         print(f"DEBUG: Unexpected dict response: {text}")
         return {"answer": "죄송합니다. 서버 응답을 처리하는 중 문제가 발생했습니다."}

    return {"answer": text}

@app.get("/")
def root():
    return {"msg": "FASTAPI OK"}