"""Non-interactive metrics run for diploma documentation."""
from __future__ import annotations

import torch

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


def main() -> None:
    train_samples, val_samples, test_samples = split_dataset(
        PLAYER_SAMPLES, train_ratio=0.7, val_ratio=0.15, seed=42
    )
    print(f"Dataset size: {len(PLAYER_SAMPLES)}")
    print(f"  Train: {len(train_samples)}")
    print(f"  Val: {len(val_samples)}")
    print(f"  Test: {len(test_samples)}")

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

    print("Training LSTM (500 epochs)...")
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

    train_loss, train_acc = evaluate_model(
        model, train_batch, train_lengths, train_labels
    )
    val_loss, val_acc = evaluate_model(model, val_batch, val_lengths, val_labels)
    test_loss, test_acc = evaluate_model(model, test_batch, test_lengths, test_labels)

    print("=== METRICS ===")
    print(f"Train loss: {train_loss:.4f}, Train accuracy: {train_acc:.2f}%")
    print(f"Val loss: {val_loss:.4f}, Val accuracy: {val_acc:.2f}%")
    print(f"Test loss: {test_loss:.4f}, Test accuracy: {test_acc:.2f}%")
    print(f"Final train loss (epoch 500): {history['train_loss'][-1]:.4f}")
    print(f"Final val loss (epoch 500): {history['val_loss'][-1]:.4f}")
    print(f"Final train acc (epoch 500): {history['train_acc'][-1]:.2f}%")
    print(f"Final val acc (epoch 500): {history['val_acc'][-1]:.2f}%")
    print(f"Num classes: {len(endings)}")
    print(f"Vocab size: {len(vocab)}")
    print(f"Classes: {endings}")


if __name__ == "__main__":
    main()
