import torch
from torchvision import models
import torch.nn as nn

# クラス数は実際の学習結果に合わせて修正
NUM_CLASSES = 28  # 実際の学習結果のクラス数

# モデル定義
model = models.resnet18(pretrained=False)
model.fc = nn.Linear(model.fc.in_features, NUM_CLASSES)
model.load_state_dict(torch.load('models/plantdoc_resnet18.pth', map_location='cpu'))
model.eval()

dummy_input = torch.randn(1, 3, 224, 224)
torch.onnx.export(model, dummy_input, "models/plantdoc_resnet18.onnx", 
                  input_names=['input'], output_names=['output'], 
                  dynamic_axes={'input': {0: 'batch_size'}, 'output': {0: 'batch_size'}})
print("ONNXファイルを出力しました: models/plantdoc_resnet18.onnx") 