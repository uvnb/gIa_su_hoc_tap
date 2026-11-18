"""Triển khai Cú Brain lên Hugging Face Spaces (miễn phí, không cần thẻ) – dữ liệu lưu ở Google Firestore.

Chạy lại mỗi khi sửa backend:
    python scripts/deploy_hf.py --token-file D:/tools/hf_token.txt --sa-file D:/tools/cu-brain-sa.json

- Code lấy từ thư mục backend/ (app/, Dockerfile, requirements*.txt) – KHÔNG gửi .env, data/, tests/.
- Khóa bí mật (GEMINI_API_KEY, APP_SHARED_SECRET lấy trong backend/.env; khóa Firestore lấy từ --sa-file)
  được cất vào mục "Secrets" của Space, không nằm trong code. Script không in khóa ra màn hình.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

from huggingface_hub import HfApi

ROOT = Path(__file__).resolve().parents[1]
SPACE_README = """---
title: Cu To Mo Brain
emoji: 🦉
colorFrom: yellow
colorTo: blue
sdk: docker
app_port: 8080
pinned: false
short_description: Máy chủ gia sư AI Cú Tò Mò (không bao giờ nói đáp án)
---

# 🦉 Cú Brain

Máy chủ của ứng dụng **Cú Tò Mò** – gia sư AI cho học sinh tiểu học. Chỉ ứng dụng có mã bí mật mới gọi được.
Kiểm tra: `GET /v1/health`.
"""


def read_env(path: Path) -> dict[str, str]:
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*([A-Z_]+)\s*=\s*(\S+)\s*$", line)
        if m and not m.group(2).endswith("..."):
            out[m.group(1)] = m.group(2)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--token-file", required=True)
    ap.add_argument("--sa-file", required=True, help="khóa JSON tài khoản dịch vụ Firestore")
    ap.add_argument("--space", default="cu-to-mo-brain")
    ap.add_argument("--provider", default="gemini")
    ap.add_argument("--code-only", action="store_true", help="chỉ cập nhật code, không đặt lại secret")
    a = ap.parse_args()

    api = HfApi(token=Path(a.token_file).read_text(encoding="utf-8").strip())
    user = api.whoami()["name"]
    repo = f"{user}/{a.space}"
    api.create_repo(repo, repo_type="space", space_sdk="docker", exist_ok=True)

    if not a.code_only:
        env = read_env(ROOT / ".env")
        secrets = {
            "APP_SHARED_SECRET": env["APP_SHARED_SECRET"],
            "FIRESTORE_CREDENTIALS_JSON": Path(a.sa_file).read_text(encoding="utf-8"),
        }
        key_name = {"gemini": "GEMINI_API_KEY", "deepseek": "DEEPSEEK_API_KEY",
                    "openrouter": "OPENROUTER_API_KEY", "anthropic": "ANTHROPIC_API_KEY"}[a.provider]
        secrets[key_name] = env[key_name]
        for k, v in secrets.items():
            api.add_space_secret(repo, k, v)
        variables = {"STORE_BACKEND": "firestore", "OCR_MODE": "off", "DEFAULT_PROVIDER": a.provider}
        for role in ("SOLVER", "TUTOR", "CHECKER", "GUARD"):
            variables[f"{role}_PROVIDER"] = a.provider
        for k, v in variables.items():
            api.add_space_variable(repo, k, v)
        print(f"Đã cất {len(secrets)} khóa bí mật và {len(variables)} biến cấu hình vào Space.")

    api.upload_file(path_or_fileobj=SPACE_README.encode("utf-8"), path_in_repo="README.md",
                    repo_id=repo, repo_type="space", commit_message="README")
    api.upload_folder(
        folder_path=str(ROOT), repo_id=repo, repo_type="space", commit_message="Cập nhật Cú Brain",
        allow_patterns=["app/**", "Dockerfile", "requirements.txt", "requirements-cloud.txt", ".dockerignore"],
        ignore_patterns=["**/__pycache__/**", "*.pyc", ".env*", "data/**", "tests/**"],
    )
    host = f"https://{user}-{a.space}.hf.space".replace("_", "-").lower()
    print(f"Đã gửi code. Space: https://huggingface.co/spaces/{repo}")
    print(f"Địa chỉ máy chủ: {host}")


if __name__ == "__main__":
    main()
