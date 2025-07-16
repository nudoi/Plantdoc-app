import os
import torch
import torch.nn as nn
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader
import requests
import zipfile
import shutil
from sklearn.model_selection import train_test_split
import random
from tqdm import tqdm

# MPSバックエンドの確認
if torch.backends.mps.is_available():
    print("MPSバックエンドが利用可能です")

def download_dataset():
    """PlantDocデータセットを自動ダウンロード・解凍"""
    dataset_url = "https://github.com/pratikkayal/PlantDoc-Dataset/archive/refs/heads/master.zip"
    zip_path = "PlantDoc-Dataset.zip"
    extract_path = "PlantDoc-Dataset"
    
    # 既にデータセットが存在する場合はスキップ
    if os.path.exists("PlantDoc-Dataset/train") and os.path.exists("PlantDoc-Dataset/val"):
        print("データセットは既に存在します。スキップします。")
        return
    
    print("PlantDocデータセットをダウンロード中...")
    
    # ダウンロード
    response = requests.get(dataset_url, stream=True)
    total_size = int(response.headers.get('content-length', 0))
    
    with open(zip_path, 'wb') as f:
        with tqdm(total=total_size, unit='B', unit_scale=True, desc="ダウンロード") as pbar:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
                    pbar.update(len(chunk))
    
    print("ダウンロード完了。解凍中...")
    
    # 解凍
    with zipfile.ZipFile(zip_path, 'r') as zip_ref:
        file_list = zip_ref.namelist()
        with tqdm(total=len(file_list), desc="解凍") as pbar:
            for file in file_list:
                zip_ref.extract(file)
                pbar.update(1)
    
    # フォルダ名を統一
    if os.path.exists("PlantDoc-Dataset-master"):
        if os.path.exists(extract_path):
            shutil.rmtree(extract_path)
        shutil.move("PlantDoc-Dataset-master", extract_path)
    
    # 一時ファイル削除
    if os.path.exists(zip_path):
        os.remove(zip_path)
    
    # データセット構造の確認
    print("データセット構造を確認中...")
    if os.path.exists(extract_path):
        contents = os.listdir(extract_path)
        print(f"PlantDoc-Dataset内のフォルダ: {contents}")
        
        # 各フォルダの内容を確認
        for item in contents:
            item_path = os.path.join(extract_path, item)
            if os.path.isdir(item_path):
                files = os.listdir(item_path)
                image_files = [f for f in files if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.tiff'))]
                print(f"  {item}: {len(image_files)}個の画像ファイル")
    
    print("データセットの準備が完了しました。")

def prepare_dataset():
    """データセットをtrain/valに分割（既に分割済みの場合はスキップ）"""
    dataset_path = "PlantDoc-Dataset"
    
    # 既にtrain/valフォルダが存在する場合はスキップ
    if os.path.exists(os.path.join(dataset_path, "train")) and os.path.exists(os.path.join(dataset_path, "val")):
        print("データセットは既にtrain/valに分割済みです。スキップします。")
        return
    
    # クラスフォルダを取得
    class_folders = [f for f in os.listdir(dataset_path) 
                    if os.path.isdir(os.path.join(dataset_path, f))]
    
    print(f"見つかったクラスフォルダ: {class_folders}")
    
    train_dir = os.path.join(dataset_path, "train")
    val_dir = os.path.join(dataset_path, "val")
    
    # train/valディレクトリを作成
    os.makedirs(train_dir, exist_ok=True)
    os.makedirs(val_dir, exist_ok=True)
    
    for class_name in tqdm(class_folders, desc="データセット分割"):
        class_path = os.path.join(dataset_path, class_name)
        if class_name in ["train", "val"]:
            continue
            
        # クラス内の画像ファイルを取得
        image_files = [f for f in os.listdir(class_path) 
                      if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.tiff'))]
        
        print(f"クラス '{class_name}': {len(image_files)}個の画像ファイル")
        
        # 画像ファイルが0個の場合はスキップ
        if len(image_files) == 0:
            print(f"警告: クラス '{class_name}' に画像ファイルが見つかりません。スキップします。")
            continue
        
        # train/valに分割（8:2）
        train_files, val_files = train_test_split(image_files, test_size=0.2, random_state=42)
        
        # trainディレクトリにコピー
        train_class_dir = os.path.join(train_dir, class_name)
        os.makedirs(train_class_dir, exist_ok=True)
        for file in train_files:
            src = os.path.join(class_path, file)
            dst = os.path.join(train_class_dir, file)
            shutil.copy2(src, dst)
        
        # valディレクトリにコピー
        val_class_dir = os.path.join(val_dir, class_name)
        os.makedirs(val_class_dir, exist_ok=True)
        for file in val_files:
            src = os.path.join(class_path, file)
            dst = os.path.join(val_class_dir, file)
            shutil.copy2(src, dst)
    
    # 最終確認
    train_classes = [f for f in os.listdir(train_dir) if os.path.isdir(os.path.join(train_dir, f))]
    val_classes = [f for f in os.listdir(val_dir) if os.path.isdir(os.path.join(val_dir, f))]
    
    print(f"データセット分割完了:")
    print(f"  train: {len(train_classes)}クラス")
    print(f"  val: {len(val_classes)}クラス")
    
    if len(train_classes) == 0:
        raise ValueError("有効なクラスが見つかりませんでした。データセットの構造を確認してください。")

# データセットの準備
download_dataset()
prepare_dataset()

# データセットの構造確認
def check_dataset_structure():
    """データセットの構造を確認"""
    dataset_path = "PlantDoc-Dataset"
    train_dir = os.path.join(dataset_path, "train")
    val_dir = os.path.join(dataset_path, "val")
    
    print("\n=== データセット構造確認 ===")
    
    if os.path.exists(train_dir):
        train_classes = [f for f in os.listdir(train_dir) if os.path.isdir(os.path.join(train_dir, f))]
        print(f"trainフォルダ: {len(train_classes)}クラス")
        for cls in train_classes[:5]:  # 最初の5クラスのみ表示
            cls_path = os.path.join(train_dir, cls)
            files = [f for f in os.listdir(cls_path) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.tiff'))]
            print(f"  {cls}: {len(files)}個の画像")
        if len(train_classes) > 5:
            print(f"  ... 他 {len(train_classes) - 5}クラス")
    
    if os.path.exists(val_dir):
        val_classes = [f for f in os.listdir(val_dir) if os.path.isdir(os.path.join(val_dir, f))]
        print(f"valフォルダ: {len(val_classes)}クラス")
        for cls in val_classes[:5]:  # 最初の5クラスのみ表示
            cls_path = os.path.join(val_dir, cls)
            files = [f for f in os.listdir(cls_path) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.bmp', '.tiff'))]
            print(f"  {cls}: {len(files)}個の画像")
        if len(val_classes) > 5:
            print(f"  ... 他 {len(val_classes) - 5}クラス")
    
    print("========================\n")

check_dataset_structure()

# データセットのパス
DATA_DIR = './PlantDoc-Dataset/'

# データ前処理
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
])

# データセットの読み込み
train_dir = os.path.join(DATA_DIR, 'train')
val_dir = os.path.join(DATA_DIR, 'val')

if not os.path.exists(train_dir) or not os.path.exists(val_dir):
    raise FileNotFoundError('train/valディレクトリが見つかりません。データセットを正しい構造で配置してください。')

original_train_dataset = datasets.ImageFolder(train_dir, transform=transform)

# valフォルダが空の場合は、trainデータから検証データを作成
if len(os.listdir(val_dir)) == 0:
    print("valフォルダが空です。trainデータから検証データを作成します。")
    
    # trainデータを8:2に分割
    train_size = int(0.8 * len(original_train_dataset))
    val_size = len(original_train_dataset) - train_size
    train_dataset, val_dataset = torch.utils.data.random_split(original_train_dataset, [train_size, val_size])
    
    print(f"train/val分割: {len(train_dataset)}/{len(val_dataset)}サンプル")
    num_classes = len(original_train_dataset.classes)
else:
    val_dataset = datasets.ImageFolder(val_dir, transform=transform)
    train_dataset = original_train_dataset
    num_classes = len(train_dataset.classes)

print(f"学習データ: {len(train_dataset)}サンプル")
print(f"検証データ: {len(val_dataset)}サンプル")
print(f"クラス数: {num_classes}")

train_loader = DataLoader(train_dataset, batch_size=32, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=32, shuffle=False)

# モデルの用意（例: ResNet18）
model = models.resnet18(weights=models.ResNet18_Weights.IMAGENET1K_V1)
model.fc = nn.Linear(model.fc.in_features, num_classes)

device = torch.device('mps' if torch.backends.mps.is_available() else 'cuda' if torch.cuda.is_available() else 'cpu')
model = model.to(device)

print(f"使用デバイス: {device}")
if device.type == 'mps':
    print("Metal Performance Shaders (MPS) を使用しています")
elif device.type == 'cuda':
    print("CUDA GPU を使用しています")
else:
    print("CPU を使用しています")

# 損失関数と最適化手法
criterion = nn.CrossEntropyLoss()
optimizer = torch.optim.Adam(model.parameters(), lr=1e-4)

# 学習ループ
EPOCHS = 10
for epoch in range(EPOCHS):
    # 学習
    model.train()
    running_loss = 0.0
    for images, labels in tqdm(train_loader, desc=f"Epoch {epoch+1}/{EPOCHS} Train"):
        images, labels = images.to(device), labels.to(device)
        outputs = model(images)
        loss = criterion(outputs, labels)
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
    
    # 検証
    model.eval()
    val_loss = 0.0
    correct = 0
    total = 0
    with torch.no_grad():
        for images, labels in tqdm(val_loader, desc=f"Epoch {epoch+1}/{EPOCHS} Val"):
            images, labels = images.to(device), labels.to(device)
            outputs = model(images)
            loss = criterion(outputs, labels)
            val_loss += loss.item()
            
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
    
    train_loss = running_loss / len(train_loader)
    val_loss = val_loss / len(val_loader)
    val_accuracy = 100 * correct / total
    
    print(f'Epoch {epoch+1}/{EPOCHS}:')
    print(f'  Train Loss: {train_loss:.4f}')
    print(f'  Val Loss: {val_loss:.4f}')
    print(f'  Val Accuracy: {val_accuracy:.2f}%')
    print('---')

# モデル保存
os.makedirs('models', exist_ok=True)
torch.save(model.state_dict(), 'models/plantdoc_resnet18.pth')
print('モデルをmodels/plantdoc_resnet18.pthに保存しました') 