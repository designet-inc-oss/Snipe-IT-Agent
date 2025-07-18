import requests
import urllib3
from snipe_config import SNIPE_URL, API_TOKEN

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

HEADERS = {
    "Authorization": f"Bearer {API_TOKEN}",
    "Accept": "application/json",
    "Content-Type": "application/json",
}

# --- get all model in Snipe-IT ---
def get_model_list():
    url = f"{SNIPE_URL}/models"
    page = 1
    per_page = 50  # can be increased as needed

    print("📋 モデルID一覧：")
    while True:
        params = {"limit": per_page, "offset": (page - 1) * per_page}
        response = requests.get(url, headers=HEADERS, params=params, verify=False)
        if response.status_code == 200:
            data = response.json()
            models = data.get("rows", [])
            if not models:
                break
            for model in models:
                print(f"ID: {model['id']}, Name: {model['name']}")
            if len(models) < per_page:
                break
            page += 1
        else:
            print("❌ モデル一覧の取得に失敗しました")
            print(response.status_code, response.text)
            break

if __name__ == "__main__":
    get_model_list()

