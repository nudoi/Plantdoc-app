import coremltools as ct
import torch
from torchvision import models
import torch.nn as nn

# クラス数
NUM_CLASSES = 28

# PyTorchモデルの読み込み
model = models.resnet18(pretrained=False)
model.fc = nn.Linear(model.fc.in_features, NUM_CLASSES)
model.load_state_dict(torch.load('models/plantdoc_resnet18.pth', map_location='cpu'))
model.eval()

# TorchScriptに変換
dummy_input = torch.randn(1, 3, 224, 224)
traced_model = torch.jit.trace(model, dummy_input)

# TorchScript→CoreML変換
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.TensorType(shape=(1, 3, 224, 224))],
    minimum_deployment_target=ct.target.iOS16
)

# 保存（ML Program形式のため.mlpackage拡張子を使用）
mlmodel_path = "models/plantdoc_resnet18.mlpackage"
mlmodel.save(mlmodel_path)
print(f"CoreMLモデルを出力しました: {mlmodel_path}") 