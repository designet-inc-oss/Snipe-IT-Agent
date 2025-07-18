import requests
import urllib3
from snipe_config import SNIPE_URL, API_TOKEN

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

HEADERS = {
    "Authorization": f"Bearer {API_TOKEN}",
    "Accept": "application/json",
    "Content-Type": "application/json",
}

# --- get all fieldset in Snipe-IT ---
def get_fieldsets():
    url = f"{SNIPE_URL}/fieldsets"
    page = 1
    per_page = 50  # can be increased as needed

    print("📋 フィールドセット一覧（ID → 名前）:")
    while True:
        params = {"limit": per_page, "offset": (page - 1) * per_page}
        response = requests.get(url, headers=HEADERS, params=params, verify=False)

        if response.status_code == 200:
            data = response.json()
            sets = data.get("rows", [])
            if not sets:
                break
            for fs in sets:
                print(f" - ID: {fs['id']}, Name: {fs['name']}")
            if len(sets) < per_page:
                break
            page += 1
        else:
            print("❌ フィールドセット一覧の取得に失敗しました")
            print(response.status_code, response.text)
            break

if __name__ == "__main__":
    get_fieldsets()
