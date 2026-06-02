# Обучение ONNX-модели локально (результат: ml/models/)
$ErrorActionPreference = "Stop"
Set-Location (Join-Path (Split-Path $PSScriptRoot -Parent) "ml")
pip install -r requirements.txt
py -3 scripts/train_model.py
