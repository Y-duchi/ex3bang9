from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Dict, Any
import pymysql
import os
from pathlib import Path

from config.local_env import load_env_file

load_env_file(Path(__file__).resolve().parent / ".env.local")

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_connection():
    return pymysql.connect(
        host=os.getenv("DB_HOST", "127.0.0.1"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "bang9"),
        password=os.getenv("DB_PASSWORD", ""),
        db=os.getenv("DB_NAME", "bang9_db"),
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor
    )


@app.get("/health")
def health():
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT COUNT(*) AS count FROM new_furniture")
            result = cursor.fetchone()
        return {"status": "ok", "furniture_count": result["count"]}
    finally:
        conn.close()

class KeptItem(BaseModel):
    product_id: str
    set_index: int

class RecommendRequest(BaseModel):
    budget: int
    furnitureTypes: List[str]
    category: str
    keptItems: List[KeptItem]

@app.post("/recommend_sets")
def recommend_sets(req: RecommendRequest):
    conn = get_connection()
    cursor = conn.cursor()

    kept_dict: Dict[int, List[Dict[str, Any]]] = {0: [], 1: [], 2: []}
    all_kept_ids = set()

    for item in req.keptItems:
        all_kept_ids.add(item.product_id)
        query = """
            SELECT nf.product_id, nf.name, nf.brand, nfo.price, nf.category, nf.style,
                   (SELECT nfi.image_url 
                    FROM new_furniture_images nfi 
                    WHERE nfi.product_id = nf.product_id 
                    LIMIT 1) AS image_url
            FROM new_furniture nf
            JOIN new_furniture_options nfo ON nf.product_id = nfo.product_id
            WHERE nf.product_id = %s
        """
        cursor.execute(query, (item.product_id,))
        result = cursor.fetchone()
        if result:
            kept_dict[item.set_index].append(result)

    result_sets = []

    for set_index in range(3):
        result_set = list(kept_dict[set_index])
        used_ids = set(all_kept_ids)
        fixed_price = sum(item["price"] for item in result_set)
        total_price = fixed_price

        kept_categories = set(item['category'] for item in result_set)
        remaining_types = [ft for ft in req.furnitureTypes if ft not in kept_categories]

        for f_type in remaining_types:
            placeholders = ','.join(['%s'] * len(used_ids)) if used_ids else '%s'
            exclude_ids = list(used_ids) if used_ids else ['-1']

            if req.category == "전체":
                query = f"""
                    SELECT nf.product_id, nf.name, nf.brand, nfo.price, nf.category, nf.style,
                           (SELECT nfi.image_url 
                            FROM new_furniture_images nfi 
                            WHERE nfi.product_id = nf.product_id 
                            LIMIT 1) AS image_url
                    FROM new_furniture nf
                    JOIN new_furniture_options nfo ON nf.product_id = nfo.product_id
                    WHERE nf.category = %s AND nf.product_id NOT IN ({placeholders})
                    ORDER BY RAND()
                    LIMIT 1
                """
                params = [f_type] + exclude_ids
            else:
                query = f"""
                    SELECT nf.product_id, nf.name, nf.brand, nfo.price, nf.category, nf.style,
                           (SELECT nfi.image_url 
                            FROM new_furniture_images nfi 
                            WHERE nfi.product_id = nf.product_id 
                            LIMIT 1) AS image_url
                    FROM new_furniture nf
                    JOIN new_furniture_options nfo ON nf.product_id = nfo.product_id
                    WHERE nf.category = %s AND nf.style = %s AND nf.product_id NOT IN ({placeholders})
                    ORDER BY RAND()
                    LIMIT 1
                """
                params = [f_type, req.category] + exclude_ids

            cursor.execute(query, params)
            item = cursor.fetchone()
            if item and (total_price + item['price']) <= req.budget:
                result_set.append(item)
                total_price += item['price']
                used_ids.add(item['product_id'])

        result_sets.append({
            "totalPrice": total_price,
            "items": result_set
        })

    cursor.close()
    conn.close()
    return result_sets
