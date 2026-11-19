"""Triển khai Cú Brain lên Vercel (gói Hobby miễn phí, không cần thẻ) – dữ liệu lưu ở Google Firestore.

Chạy lại mỗi khi sửa backend:
    python scripts/deploy_vercel.py --token-file D:/tools/vercel_token.txt --sa-file D:/tools/cu-brain-sa.json
    (thêm --code-only nếu chỉ sửa code, không cần đặt lại khóa)

Cách làm: gom app/ + requirements + vercel.json vào thư mục tạm → `npx vercel deploy --prod`.
Khóa bí mật (GEMINI_API_KEY, APP_SHARED_SECRET trong backend/.env; khóa Firestore từ --sa-file) cất vào
Environment Variables của dự án Vercel (mã hóa), không nằm trong code. Script không in khóa ra màn hình.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = "cu-to-mo-brain"

# Vercel tự nhận đây là dự án FastAPI và chạy `app` trong app/main.py – không cần rewrites
# (rewrites sẽ đổi đường dẫn mà FastAPI nhận được → 404).
VERCEL_JSON = {
    "regions": ["sin1"],  # Singapore – gần Việt Nam
}


def read_env(path: Path) -> dict[str, str]:
    out = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*([A-Z_]+)\s*=\s*(\S+)\s*$", line)
        if m and not m.group(2).endswith("..."):
            out[m.group(1)] = m.group(2)
    return out


def run(args: list[str], cwd: Path, stdin: str | None = None, quiet: bool = False) -> str:
    p = subprocess.run(args, cwd=cwd, input=stdin, capture_output=True, text=True, encoding="utf-8",
                       shell=True)
    if p.returncode != 0:
        raise SystemExit(f"Lỗi: {' '.join(a for a in args if not a.startswith('--token'))}\n{p.stderr[-1500:]}")
    if not quiet:
        print(p.stdout.strip()[-600:])
    return p.stdout


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--token-file", required=True)
    ap.add_argument("--sa-file", required=True)
    ap.add_argument("--provider", default="gemini")
    ap.add_argument("--code-only", action="store_true")
    a = ap.parse_args()
    token = Path(a.token_file).read_text(encoding="utf-8").strip()
    vc = ["npx", "--yes", "vercel@latest"]
    tok = [f"--token={token}"]

    stage = Path(tempfile.mkdtemp(prefix="cu-vercel-"))
    shutil.copytree(ROOT / "app", stage / "app", ignore=shutil.ignore_patterns("__pycache__", "*.pyc"))
    # Giọng Cú tự nhiên (Piper vais1000, 64 MB): lấy từ app Flutter (tải bằng app/tool/fetch_tts_model.py)
    voice = ROOT.parent / "app" / "assets" / "tts" / "vi"
    if not (voice / "vi.onnx").exists():
        subprocess.run([sys.executable, str(ROOT.parent / "app" / "tool" / "fetch_tts_model.py")], check=True)
    shutil.copytree(voice, stage / "app" / "tts_model")
    # Vercel bỏ các file .so đi kèm gói sherpa-onnx khi đóng gói → tự mang theo (app/tts.py nạp trước)
    sherpa_ver = next(l.split("==")[1].strip() for l in (ROOT / "requirements-cloud.txt").read_text(
        encoding="utf-8").splitlines() if l.startswith("sherpa-onnx=="))
    wheels = Path(tempfile.mkdtemp(prefix="cu-wheels-"))
    subprocess.run([sys.executable, "-m", "pip", "download", "-q", "--no-deps", "--only-binary=:all:",
                    "--platform", "manylinux2014_x86_64", "--python-version", "3.12",
                    f"sherpa-onnx=={sherpa_ver}", f"sherpa-onnx-core=={sherpa_ver}", "-d", str(wheels)], check=True)
    (stage / "app" / "tts_lib").mkdir()
    for whl in wheels.glob("*.whl"):
        with zipfile.ZipFile(whl) as z:
            for n in z.namelist():
                base = n.rsplit("/", 1)[-1]
                if base.startswith(("libonnxruntime.so", "libasound")):
                    (stage / "app" / "tts_lib" / base).write_bytes(z.read(n))
    shutil.rmtree(wheels, ignore_errors=True)
    (stage / ".python-version").write_text("3.12\n", encoding="utf-8")
    reqs = [l for l in (ROOT / "requirements.txt").read_text(encoding="utf-8").splitlines()
            if l.strip() and not l.startswith("#") and not l.startswith("uvicorn")]
    reqs += [l for l in (ROOT / "requirements-cloud.txt").read_text(encoding="utf-8").splitlines()
             if l.strip() and not l.startswith(("#", "-r"))]
    (stage / "requirements.txt").write_text("\n".join(reqs) + "\n", encoding="utf-8")
    (stage / "vercel.json").write_text(json.dumps(VERCEL_JSON, indent=2), encoding="utf-8")
    (stage / ".vercelignore").write_text(".env\n*.sqlite3*\n__pycache__\n", encoding="utf-8")

    # gắn thư mục tạm với dự án (tạo nếu chưa có)
    run(vc + ["link", "--yes", f"--project={PROJECT}"] + tok, stage, quiet=True)

    if not a.code_only:
        env = read_env(ROOT / ".env")
        key_name = {"gemini": "GEMINI_API_KEY", "deepseek": "DEEPSEEK_API_KEY",
                    "openrouter": "OPENROUTER_API_KEY", "anthropic": "ANTHROPIC_API_KEY"}[a.provider]
        values = {
            "APP_SHARED_SECRET": env["APP_SHARED_SECRET"],
            key_name: env[key_name],
            "FIRESTORE_CREDENTIALS_JSON": json.dumps(json.loads(Path(a.sa_file).read_text(encoding="utf-8"))),
            "STORE_BACKEND": "firestore",
            "OCR_MODE": "off",
            "CORS_ORIGIN_REGEX": "off",
            "WEB_DIR": "/tmp/no-web",
            "DB_PATH": "/tmp/cutomo.sqlite3",
            "DEFAULT_PROVIDER": a.provider,
        }
        for role in ("SOLVER", "TUTOR", "CHECKER", "GUARD"):
            values[f"{role}_PROVIDER"] = a.provider
        for k, v in values.items():
            subprocess.run(vc + ["env", "rm", k, "production", "--yes"] + tok, cwd=stage, shell=True,
                           capture_output=True, text=True)
            run(vc + ["env", "add", k, "production"] + tok, stage, stdin=v, quiet=True)
        print(f"Đã cất {len(values)} biến môi trường (khóa được mã hóa) vào dự án Vercel.")

    out = run(vc + ["deploy", "--prod", "--yes"] + tok, stage, quiet=True)
    print("Đã triển khai. Địa chỉ chính: https://" + PROJECT + ".vercel.app")
    shutil.rmtree(stage, ignore_errors=True)


if __name__ == "__main__":
    main()
