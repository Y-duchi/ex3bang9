from __future__ import annotations

import os
from pathlib import Path
import sys

import pymysql

BACKEND_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BACKEND_DIR))

from config.local_env import load_env_file


load_env_file(BACKEND_DIR / ".env.local")
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

import django

django.setup()

from django.contrib.auth.hashers import make_password


def main() -> None:
    connection = pymysql.connect(
        host=os.getenv("DB_HOST", "127.0.0.1"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "bang9"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "bang9_db"),
        charset="utf8mb4",
        autocommit=True,
    )

    password_hash = make_password("portfolio")
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO users (
                    user_id, password_hash, username, nickname, phone, email,
                    points, certification, login_type, profile_image
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, NULL)
                ON DUPLICATE KEY UPDATE
                    password_hash = VALUES(password_hash),
                    username = VALUES(username),
                    nickname = VALUES(nickname),
                    points = VALUES(points),
                    certification = VALUES(certification),
                    login_type = VALUES(login_type)
                """,
                (
                    "portfolio_demo",
                    password_hash,
                    "포트폴리오 데모",
                    "방꾸석 데모",
                    "01000000000",
                    "demo@local.invalid",
                    2500,
                    True,
                    "portfolio_demo",
                ),
            )
    finally:
        connection.close()

    print("portfolio_demo user is ready")


if __name__ == "__main__":
    main()
