"""
Отдельные рисунки для диплома (matplotlib).

Запуск:
    py -3 visualize_diploma.py

Файлы в docs/diagrams/:
    fig_4_1_architecture_flow.png      — блок-схема модели
    fig_4_2_computational_graph.png    — граф с размерностями тензоров
    fig_6_1_training_loss.png          — функция потерь (4.11)
    fig_6_2_training_accuracy.png      — точность (4.15)
    fig_6_3_validation_combined.png    — val loss + val accuracy
    fig_6_4_confusion_matrix.png       — матрица ошибок
    fig_6_5_metrics_bars.png           — loss и accuracy по выборкам
    fig_6_6_per_class_accuracy.png     — точность по классам
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import torch
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

torch.manual_seed(42)

from dataset import PLAYER_SAMPLES, split_dataset
from lstm_prototype import (
    QuestLSTM,
    QuestLSTMConfig,
    build_vocab,
    encode_samples,
    evaluate_model,
    train_model,
)

OUTPUT_DIR = Path(__file__).resolve().parents[3] / "docs" / "diagrams"

plt.rcParams.update(
    {
        "font.sans-serif": ["Segoe UI", "Arial", "DejaVu Sans"],
        "axes.unicode_minus": False,
        "figure.dpi": 120,
        "savefig.dpi": 300,
    }
)


def train_and_collect():
    train_samples, val_samples, test_samples = split_dataset(
        PLAYER_SAMPLES, train_ratio=0.7, val_ratio=0.15, seed=42
    )
    vocab = build_vocab(PLAYER_SAMPLES)
    endings = sorted({label for _, label in PLAYER_SAMPLES})
    label_to_idx = {label: idx for idx, label in enumerate(endings)}

    train_batch, train_lengths, train_labels = encode_samples(
        train_samples, vocab, label_to_idx
    )
    val_batch, val_lengths, val_labels = encode_samples(
        val_samples, vocab, label_to_idx
    )
    test_batch, test_lengths, test_labels = encode_samples(
        test_samples, vocab, label_to_idx
    )

    cfg = QuestLSTMConfig()
    model = QuestLSTM(len(vocab), vocab["<pad>"], len(endings), cfg)
    history = train_model(
        model,
        train_batch,
        train_lengths,
        train_labels,
        val_batch,
        val_lengths,
        val_labels,
        cfg,
    )

    metrics = {
        "train": evaluate_model(model, train_batch, train_lengths, train_labels),
        "val": evaluate_model(model, val_batch, val_lengths, val_labels),
        "test": evaluate_model(model, test_batch, test_lengths, test_labels),
    }
    return model, history, metrics, endings, test_batch, test_lengths, test_labels


def build_confusion_matrix(model, batch, lengths, labels, n_classes):
    model.eval()
    with torch.no_grad():
        preds = model(batch, lengths).argmax(dim=1).cpu().numpy()
    y_true = labels.cpu().numpy()
    cm = np.zeros((n_classes, n_classes), dtype=int)
    for t, p in zip(y_true, preds):
        cm[t, p] += 1
    return cm


def plot_architecture_flow(out: Path) -> None:
    fig, ax = plt.subplots(figsize=(14, 3.5))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 3)
    ax.axis("off")

    blocks = [
        (0.3, "Телеметрия\nx₁…x_T"),
        (2.2, "Embedding\nd = 32\n(4.1)"),
        (4.5, "LSTM\nh = 64\n(4.2–4.7)"),
        (6.8, "Mean Pooling\n(4.8)"),
        (9.0, "FC + ReLU\n(4.9)"),
        (11.2, "Softmax\n(4.10)"),
        (12.8, "Архетип\n+ confidence\n(5.1)"),
    ]

    for i, (x, text) in enumerate(blocks):
        ax.add_patch(
            FancyBboxPatch(
                (x, 0.8),
                1.5,
                1.4,
                boxstyle="round,pad=0.08",
                linewidth=1.5,
                edgecolor="#1e40af",
                facecolor="#dbeafe" if i % 2 == 0 else "#ecfdf5",
            )
        )
        ax.text(x + 0.75, 1.5, text, ha="center", va="center", fontsize=9)
        if i < len(blocks) - 1:
            ax.add_patch(
                FancyArrowPatch(
                    (x + 1.55, 1.5),
                    (blocks[i + 1][0] - 0.05, 1.5),
                    arrowstyle="-|>",
                    mutation_scale=12,
                    linewidth=1.5,
                    color="#374151",
                )
            )

    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_computational_graph(model, n_classes: int, out: Path) -> None:
    fig, ax = plt.subplots(figsize=(14, 3.5))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 2.2)
    ax.axis("off")

    vocab_size = model.embedding.num_embeddings
    nodes = [
        (0.2, 1.0, f"Вход\nx₁…x_T\n|V|={vocab_size}"),
        (1.5, 1.0, "Embedding\n(4.1)"),
        (3.0, 1.0, "LSTM\n(4.2–4.7)"),
        (4.5, 1.0, "MeanPool\n(4.8)"),
        (6.0, 1.0, "FC+ReLU\n(4.9)"),
        (7.5, 1.0, "Softmax\n(4.10)"),
        (9.0, 1.0, "Выход\nŷ, conf.\n(5.1)"),
    ]
    edge_labels = ["T", "T×32", "T×64", "64", "32", str(n_classes), "p_k"]

    for i, (x, y, txt) in enumerate(nodes):
        ax.add_patch(
            FancyBboxPatch(
                (x, y - 0.45),
                1.0,
                0.9,
                boxstyle="round,pad=0.06",
                linewidth=1.4,
                edgecolor="#1d4ed8",
                facecolor="#eff6ff" if i % 2 == 0 else "#f0fdf4",
            )
        )
        ax.text(x + 0.5, y, txt, ha="center", va="center", fontsize=8.5)
        if i < len(nodes) - 1:
            x0, x1 = x + 1.02, nodes[i + 1][0] - 0.02
            ax.add_patch(
                FancyArrowPatch(
                    (x0, y),
                    (x1, y),
                    arrowstyle="-|>",
                    mutation_scale=11,
                    color="#475569",
                    lw=1.3,
                )
            )
            ax.text(
                (x0 + x1) / 2,
                y + 0.28,
                edge_labels[i],
                ha="center",
                fontsize=8,
                color="#b45309",
                fontweight="bold",
            )

    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_training_loss(history: dict, out: Path) -> None:
    epochs = history["epochs"]
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(epochs, history["train_loss"], label="Train", color="#2563eb", lw=2)
    ax.plot(epochs, history["val_loss"], label="Validation", color="#dc2626", lw=2)
    ax.set_xlabel("Эпоха")
    ax.set_ylabel("CrossEntropyLoss")
    ax.set_title("Динамика функции потерь при обучении (формула 4.11)")
    ax.legend()
    ax.grid(True, alpha=0.3)
    ax.set_xlim(0, 500)
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_training_accuracy(history: dict, out: Path) -> None:
    epochs = history["epochs"]
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(epochs, history["train_acc"], label="Train", color="#2563eb", lw=2)
    ax.plot(epochs, history["val_acc"], label="Validation", color="#dc2626", lw=2)
    ax.set_xlabel("Эпоха")
    ax.set_ylabel("Accuracy, %")
    ax.set_title("Динамика точности при обучении (формула 4.15)")
    ax.legend(loc="lower right")
    ax.grid(True, alpha=0.3)
    ax.set_ylim(30, 101)
    ax.set_xlim(0, 500)
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_validation_combined(history: dict, out: Path) -> None:
    epochs = history["epochs"]
    fig, ax = plt.subplots(figsize=(10, 5))
    ax.plot(epochs, history["val_loss"], color="#dc2626", lw=2, label="Val Loss")
    ax.set_xlabel("Эпоха")
    ax.set_ylabel("Validation Loss", color="#dc2626")
    ax.tick_params(axis="y", labelcolor="#dc2626")
    ax.grid(True, alpha=0.25)
    ax.set_xlim(0, 500)

    ax2 = ax.twinx()
    ax2.plot(epochs, history["val_acc"], color="#059669", lw=2, label="Val Accuracy")
    ax2.set_ylabel("Validation Accuracy, %", color="#059669")
    ax2.tick_params(axis="y", labelcolor="#059669")
    ax2.set_ylim(30, 101)

    lines1, labels1 = ax.get_legend_handles_labels()
    lines2, labels2 = ax2.get_legend_handles_labels()
    ax.legend(lines1 + lines2, labels1 + labels2, loc="center right")
    ax.set_title("Validation Loss и Validation Accuracy на одном графике")
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_confusion_matrix(cm, class_names: list[str], out: Path) -> None:
    n = len(class_names)
    short = [c.replace("_path", "") for c in class_names]
    fig, ax = plt.subplots(figsize=(7, 6))
    im = ax.imshow(cm, cmap="Blues")
    ax.set_xticks(range(n))
    ax.set_yticks(range(n))
    ax.set_xticklabels(short, rotation=30, ha="right")
    ax.set_yticklabels(short)
    ax.set_xlabel("Предсказанный класс")
    ax.set_ylabel("Истинный класс")
    ax.set_title(f"Матрица ошибок на тестовой выборке (n={cm.sum()})")

    for i in range(n):
        for j in range(n):
            color = "white" if cm[i, j] > cm.max() / 2 else "black"
            ax.text(j, i, str(cm[i, j]), ha="center", va="center", color=color, fontsize=12)

    fig.colorbar(im, ax=ax, fraction=0.046)
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_metrics_bars(metrics: dict, out: Path) -> None:
    splits = ["Train\n(945)", "Val\n(201)", "Test\n(204)"]
    keys = ["train", "val", "test"]
    losses = [metrics[k][0] for k in keys]
    accs = [metrics[k][1] for k in keys]
    x = np.arange(3)
    w = 0.35

    fig, ax = plt.subplots(figsize=(10, 5))
    b1 = ax.bar(x - w / 2, losses, w, color="#7c3aed", label="Loss")
    ax.set_ylabel("CrossEntropyLoss", color="#7c3aed")
    ax.set_xticks(x)
    ax.set_xticklabels(splits)
    ax.grid(True, axis="y", alpha=0.3)

    ax2 = ax.twinx()
    b2 = ax2.bar(x + w / 2, accs, w, color="#059669", alpha=0.85, label="Accuracy")
    ax2.set_ylabel("Accuracy, %", color="#059669")
    ax2.set_ylim(0, 105)

    for bar, v in zip(b1, losses):
        ax.text(bar.get_x() + bar.get_width() / 2, v + 0.02, f"{v:.4f}", ha="center", fontsize=9)
    for bar, v in zip(b2, accs):
        ax2.text(
            bar.get_x() + bar.get_width() / 2,
            v + 1,
            f"{v:.2f}%",
            ha="center",
            fontsize=9,
            fontweight="bold",
        )

    ax.set_title("Итоговые метрики LSTM по выборкам (табл. 6.1)")
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_per_class_accuracy(cm, class_names: list[str], out: Path) -> None:
    short = [c.replace("_path", "") for c in class_names]
    accs = [cm[i, i] / cm[i].sum() * 100 if cm[i].sum() else 0 for i in range(len(class_names))]

    fig, ax = plt.subplots(figsize=(8, 5))
    bars = ax.bar(short, accs, color=["#3b82f6", "#8b5cf6", "#10b981"])
    ax.set_ylabel("Accuracy, %")
    ax.set_ylim(0, 105)
    ax.set_title("Точность классификации по классам (test)")
    ax.grid(True, axis="y", alpha=0.3)
    for bar, v in zip(bars, accs):
        ax.text(bar.get_x() + bar.get_width() / 2, v + 1, f"{v:.1f}%", ha="center", fontweight="bold")
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    print("Обучение модели...")
    model, history, metrics, endings, test_batch, test_lengths, test_labels = train_and_collect()
    cm = build_confusion_matrix(model, test_batch, test_lengths, test_labels, len(endings))
    n_classes = len(endings)

    figures = [
        ("fig_4_1_architecture_flow.png", lambda p: plot_architecture_flow(p)),
        ("fig_4_2_computational_graph.png", lambda p: plot_computational_graph(model, n_classes, p)),
        ("fig_6_1_training_loss.png", lambda p: plot_training_loss(history, p)),
        ("fig_6_2_training_accuracy.png", lambda p: plot_training_accuracy(history, p)),
        ("fig_6_3_validation_combined.png", lambda p: plot_validation_combined(history, p)),
        ("fig_6_4_confusion_matrix.png", lambda p: plot_confusion_matrix(cm, endings, p)),
        ("fig_6_5_metrics_bars.png", lambda p: plot_metrics_bars(metrics, p)),
        ("fig_6_6_per_class_accuracy.png", lambda p: plot_per_class_accuracy(cm, endings, p)),
    ]

    for name, fn in figures:
        path = OUTPUT_DIR / name
        fn(path)
        print(f"  -> {path}")

    train_m, val_m, test_m = metrics["train"], metrics["val"], metrics["test"]
    print("\n=== METRICS ===")
    print(f"Train: loss={train_m[0]:.4f}, acc={train_m[1]:.2f}%")
    print(f"Val:   loss={val_m[0]:.4f}, acc={val_m[1]:.2f}%")
    print(f"Test:  loss={test_m[0]:.4f}, acc={test_m[1]:.2f}%")


if __name__ == "__main__":
    main()
