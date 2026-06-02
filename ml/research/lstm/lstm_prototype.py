"""
LSTM-модель для адаптации игрового геймплея на основе анализа последовательностей действий игрока.

Алгоритм:
1. Формирует датасет, где ключевые слова поведения ведут к финалам.
2. Обучает компактный LSTM-классификатор (PyTorch) для выбора подходящего финала.
3. Визуализирует процесс обучения (графики loss и accuracy).
4. Выводит примеры предсказаний на тестовом наборе.

Архитектура модели:
- Embedding Layer (32 измерения)
- LSTM Layer (64 скрытых единиц)
- Mean Pooling (равномерный учет всех слов)
- Классификатор (Linear → ReLU → Linear)

Запуск:
    python lstm_prototype.py

Требования:
    pip install torch matplotlib numpy

Выходные файлы:
    - training_history.png - графики процесса обучения (loss и accuracy по эпохам)
    - Консольный вывод с примерами предсказаний на тестовом наборе
"""

from __future__ import annotations

import sys
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Sequence, Tuple

try:
    import torch
    from torch import nn
    from torch.nn.utils.rnn import pack_padded_sequence, pad_packed_sequence
except ImportError as exc:  # pragma: no cover - импорт защищён
    sys.stderr.write(
        "Для запуска прототипа требуется PyTorch. Установите его через `pip install torch`.\n"
    )
    raise

try:
    import matplotlib.pyplot as plt
    import numpy as np
except ImportError:
    print("Предупреждение: matplotlib не установлен. Визуализация будет недоступна.")
    plt = None
    np = None

from dataset import PLAYER_SAMPLES, split_dataset

QUEST_GUIDE: Dict[str, Dict[str, List[str]]] = {
    "sage_path": {
        "quests": [
            "Изучить плиты в тайном архиве",
            "Договориться о перемирии с советом",
            "Собрать мифы для хроники",
        ],
        "endings": [
            "Финал «Хранитель Хроник» подчёркивает терпеливые открытия.",
            "Вы наставляете столицу и дипломатически предотвращаете катаклизм.",
        ],
    },
    "shadow_path": {
        "quests": [
            "Проникнуть в обсидиановый цитадель",
            "Отследить контрабандистов на нижних причалах",
            "Саботировать боевых големов до активации",
        ],
        "endings": [
            "Финал «Завеса Шёпота» завершается тихой сменой режима.",
            "Вы устраняете угрозы точечными ударами и тайными союзами.",
        ],
    },
    "warlord_path": {
        "quests": [
            "Защитить приграничный бастион",
            "Возглавить прорыв в израненную долину",
            "Обучить ополчения к надвигающейся осаде",
        ],
        "endings": [
            "Финал «Железный Авангард» коронует вас боевым лидером.",
            "Кланы объединяются под вашим знаменем для решающего штурма.",
        ],
    },
}


def build_vocab(samples: Sequence[Tuple[str, str]]) -> Dict[str, int]:
    tokens = {"<pad>", "<unk>"}
    for sequence, _ in samples:
        tokens.update(sequence.lower().split())
    return {token: idx for idx, token in enumerate(sorted(tokens))}


def encode_samples(
    samples: Sequence[Tuple[str, str]],
    vocab: Dict[str, int],
    label_to_idx: Dict[str, int],
) -> Tuple[torch.Tensor, torch.Tensor, torch.Tensor]:
    sequences: List[List[int]] = []
    labels: List[int] = []
    lengths: List[int] = []

    for text, label in samples:
        indices = [vocab.get(tok, vocab["<unk>"]) for tok in text.lower().split()]
        sequences.append(indices)
        labels.append(label_to_idx[label])
        lengths.append(len(indices))

    max_len = max(lengths)
    pad_idx = vocab["<pad>"]
    batch = torch.full((len(sequences), max_len), pad_idx, dtype=torch.long)
    for i, seq in enumerate(sequences):
        batch[i, : len(seq)] = torch.tensor(seq, dtype=torch.long)

    return batch, torch.tensor(lengths, dtype=torch.long), torch.tensor(labels)


@dataclass
class QuestLSTMConfig:
    embedding_dim: int = 32
    hidden_dim: int = 64
    epochs: int = 500  # Увеличено для лучшего обучения на смешанных примерах
    lr: float = 0.01
    weight_decay: float = 1e-4
    use_last_hidden: bool = False  # True = последний hidden state (для последовательного накопления), False = mean pooling (равномерный учет всех слов)
    initial_words_threshold: int = 6  # Количество слов для первого предсказания
    enable_fine_tuning: bool = False  # Включить дообучение на новых данных (отключено по умолчанию из-за закрепления ошибок)
    fine_tuning_lr: float = 0.001  # Меньший learning rate для дообучения
    use_sliding_window: bool = True  # Использовать только последние N действий для предсказания
    sliding_window_size: int = 15  # Размер окна для предсказания (None = вся история)


class QuestLSTM(nn.Module):
    def __init__(self, vocab_size: int, pad_idx: int, num_labels: int, cfg: QuestLSTMConfig):
        super().__init__()
        self.cfg = cfg
        self.embedding = nn.Embedding(vocab_size, cfg.embedding_dim, padding_idx=pad_idx)
        self.lstm = nn.LSTM(cfg.embedding_dim, cfg.hidden_dim, batch_first=True)
        self.classifier = nn.Sequential(
            nn.Linear(cfg.hidden_dim, cfg.hidden_dim // 2),
            nn.ReLU(),
            nn.Linear(cfg.hidden_dim // 2, num_labels),
        )

    def forward(self, batch: torch.Tensor, lengths: torch.Tensor) -> torch.Tensor:
        embeds = self.embedding(batch)
        packed = pack_padded_sequence(
            embeds, lengths.cpu(), batch_first=True, enforce_sorted=False
        )
        # Получаем все выходы LSTM для каждого слова в последовательности
        output, (hidden, _) = self.lstm(packed)
        
        if self.cfg.use_last_hidden:
            # Используем последний hidden state - это соответствует ТЗ:
            # LSTM накапливает информацию о последовательности действий игрока
            # Последний hidden state содержит контекст всей последовательности
            # Это важно для адаптации геймплея, где модель должна учитывать
            # всю историю действий игрока, а не только среднее
            feats = hidden[-1]  # [batch_size, hidden_dim]
        else:
            # Альтернативный режим: mean pooling для равномерного учета всех слов
            # Распаковываем последовательность обратно для pooling
            output, _ = pad_packed_sequence(output, batch_first=True)
            
            # Используем mean pooling по всем выходам (исключая padding)
            batch_size = output.size(0)
            max_len = output.size(1)
            
            # Приводим lengths к нужному устройству и формату
            lengths_expanded = lengths.to(output.device).unsqueeze(1)  # [batch_size, 1]
            
            # Создаем маску: True для реальных слов, False для padding
            mask = torch.arange(max_len, device=output.device).unsqueeze(0).expand(batch_size, -1)
            mask = (mask < lengths.to(output.device).unsqueeze(1)).unsqueeze(-1).float()
            
            # Применяем маску и вычисляем среднее по реальным словам
            masked_output = output * mask  # [batch_size, max_len, hidden_dim]
            sum_output = masked_output.sum(dim=1)  # [batch_size, hidden_dim]
            count = lengths_expanded.float()  # [batch_size, 1]
            feats = sum_output / count  # Mean pooling: [batch_size, hidden_dim]
        
        return self.classifier(feats)


def evaluate_model(
    model: QuestLSTM,
    batch: torch.Tensor,
    lengths: torch.Tensor,
    labels: torch.Tensor,
) -> Tuple[float, float]:
    """
    Оценивает модель на данных.
    
    Returns:
        Кортеж (loss, accuracy)
    """
    criterion = nn.CrossEntropyLoss()
    model.eval()
    with torch.no_grad():
        logits = model(batch, lengths)
        loss = criterion(logits, labels).item()
        preds = logits.argmax(dim=1)
        acc = (preds == labels).float().mean().item() * 100
    return loss, acc


def train_model(
    model: QuestLSTM,
    train_batch: torch.Tensor,
    train_lengths: torch.Tensor,
    train_labels: torch.Tensor,
    val_batch: Optional[torch.Tensor],
    val_lengths: Optional[torch.Tensor],
    val_labels: Optional[torch.Tensor],
    cfg: QuestLSTMConfig,
) -> Dict[str, List[float]]:
    """
    Обучает модель и возвращает историю обучения.
    
    Returns:
        Словарь с историей: {'train_loss': [...], 'train_acc': [...], 'val_loss': [...], 'val_acc': [...]}
    """
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=cfg.lr, weight_decay=cfg.weight_decay)
    
    # История обучения
    history = {
        'train_loss': [],
        'train_acc': [],
        'val_loss': [],
        'val_acc': [],
        'epochs': []
    }

    for epoch in range(cfg.epochs):
        model.train()
        optimizer.zero_grad()
        logits = model(train_batch, train_lengths)
        loss = criterion(logits, train_labels)
        loss.backward()
        optimizer.step()

        # Вычисляем метрики
        with torch.no_grad():
            train_preds = logits.argmax(dim=1)
            train_acc = (train_preds == train_labels).float().mean().item() * 100
        
        # Сохраняем историю
        history['epochs'].append(epoch + 1)
        history['train_loss'].append(loss.item())
        history['train_acc'].append(train_acc)
        
        if val_batch is not None and val_lengths is not None and val_labels is not None:
            val_loss, val_acc = evaluate_model(model, val_batch, val_lengths, val_labels)
            history['val_loss'].append(val_loss)
            history['val_acc'].append(val_acc)
            
            if (epoch + 1) % 50 == 0 or epoch == 0:
                print(
                    f"[эпоха {epoch + 1:03d}] "
                    f"train: ошибка={loss.item():.4f} точность={train_acc:.1f}% | "
                    f"val: ошибка={val_loss:.4f} точность={val_acc:.1f}%"
                )
        else:
            if (epoch + 1) % 50 == 0 or epoch == 0:
                print(f"[эпоха {epoch + 1:03d}] ошибка={loss.item():.4f} точность={train_acc:.1f}%")
    
    return history


def predict(
    model: QuestLSTM,
    vocab: Dict[str, int],
    ending_labels: List[str],
    user_tokens: Sequence[str],
    show_probs: bool = False,
) -> Tuple[str, List[str], List[str], Optional[Dict[str, float]]]:
    """
    Предсказывает стиль игрока на основе последовательности ключевых слов.
    
    Args:
        model: Обученная модель LSTM
        vocab: Словарь токенов
        ending_labels: Список меток классов
        user_tokens: Последовательность ключевых слов
        show_probs: Показывать ли вероятности всех классов
        
    Returns:
        Кортеж (ending, quests, endings, prob_dict)
    """
    encoded = [vocab.get(tok.lower(), vocab["<unk>"]) for tok in user_tokens]
    if not encoded:
        raise ValueError("Не найдены ключевые слова.")

    batch = torch.tensor(encoded, dtype=torch.long).unsqueeze(0)
    lengths = torch.tensor([len(encoded)], dtype=torch.long)

    model.eval()
    with torch.no_grad():
        logits = model(batch, lengths)
        probs = torch.softmax(logits, dim=-1).squeeze(0)
        idx = int(torch.argmax(probs))

    ending = ending_labels[idx]
    guide = QUEST_GUIDE[ending]
    
    # Возвращаем вероятности для всех классов, если нужно
    prob_dict = None
    if show_probs:
        prob_dict = {
            ending_labels[i]: float(probs[i]) * 100 
            for i in range(len(ending_labels))
        }
    
    return ending, guide["quests"], guide["endings"], prob_dict


@dataclass
class PlayerSession:
    """
    Класс для хранения истории действий игрока и управления сессией.
    Реализует механизм накопления данных и эволюции модели поведения.
    """
    action_history: List[str] = field(default_factory=list)
    prediction_history: List[Tuple[str, Dict[str, float]]] = field(default_factory=list)
    initial_threshold: int = 6
    max_history_length: int = 100  # Ограничение длины истории для производительности
    
    def add_actions(self, actions: List[str]) -> None:
        """Добавляет новые действия к истории игрока."""
        self.action_history.extend(actions)
        # Ограничиваем длину истории для производительности
        if len(self.action_history) > self.max_history_length:
            # Оставляем последние max_history_length действий
            self.action_history = self.action_history[-self.max_history_length:]
    
    def get_current_sequence(self, window_size: Optional[int] = None) -> List[str]:
        """
        Возвращает текущую последовательность действий.
        
        Args:
            window_size: Если указан, возвращает только последние N действий.
                        Если None, возвращает всю историю.
        """
        if window_size is None:
            return self.action_history.copy()
        else:
            return self.action_history[-window_size:] if len(self.action_history) > window_size else self.action_history.copy()
    
    def get_sequence_length(self) -> int:
        """Возвращает текущую длину последовательности."""
        return len(self.action_history)
    
    def has_enough_data(self) -> bool:
        """Проверяет, достаточно ли данных для первого предсказания."""
        return len(self.action_history) >= self.initial_threshold
    
    def save_prediction(self, ending: str, probs: Dict[str, float]) -> None:
        """Сохраняет предсказание в историю."""
        self.prediction_history.append((ending, probs.copy()))
    
    def get_prediction_change(self) -> Optional[str]:
        """
        Определяет, изменилось ли предсказание по сравнению с предыдущим.
        Возвращает описание изменения или None, если изменений нет.
        """
        if len(self.prediction_history) < 2:
            return None
        
        last_pred = self.prediction_history[-1][0]
        prev_pred = self.prediction_history[-2][0]
        
        if last_pred != prev_pred:
            return f"Модель изменила предсказание: {prev_pred} → {last_pred}"
        return None


def fine_tune_model(
    model: QuestLSTM,
    vocab: Dict[str, int],
    label_to_idx: Dict[str, int],
    new_samples: List[Tuple[str, str]],
    epochs: int = 5,
    lr: float = 0.001,
) -> None:
    """
    Дообучает модель на новых данных игрока.
    Это демонстрирует концепцию эволюции модели поведения.
    
    Args:
        model: Модель для дообучения
        vocab: Словарь токенов
        label_to_idx: Маппинг меток в индексы
        new_samples: Новые примеры для дообучения
        epochs: Количество эпох дообучения
        lr: Learning rate для дообучения (меньше основного)
    """
    if not new_samples:
        return
    
    # Кодируем новые данные
    batch, lengths, labels = encode_samples(new_samples, vocab, label_to_idx)
    
    criterion = nn.CrossEntropyLoss()
    optimizer = torch.optim.Adam(model.parameters(), lr=lr)
    
    model.train()
    for epoch in range(epochs):
        optimizer.zero_grad()
        logits = model(batch, lengths)
        loss = criterion(logits, labels)
        loss.backward()
        optimizer.step()
    
    model.eval()


def interactive_loop(
    model: QuestLSTM,
    vocab: Dict[str, int],
    ending_labels: List[str],
    cfg: QuestLSTMConfig,
) -> None:
    """
    Интерактивный цикл с накоплением истории действий игрока.
    
    Механизм работы:
    1. Модель ждет первые N ключевых слов (по умолчанию 6)
    2. Выдает первое предсказание
    3. Продолжает принимать новые ключевые слова
    4. Обновляет предсказание на основе накопленной истории
    5. Опционально дообучается на новых данных
    """
    session = PlayerSession(initial_threshold=cfg.initial_words_threshold)
    
    print("\n" + "="*60)
    print("🎮 ИГРОВАЯ СЕССИЯ НАЧАТА")
    print("="*60)
    print(f"\nМодель будет накапливать историю ваших действий.")
    print(f"Первое предсказание будет сделано после {cfg.initial_words_threshold} ключевых слов.")
    print("После этого модель будет обновлять предсказание на основе всей накопленной истории.")
    if cfg.enable_fine_tuning:
        print("Модель также будет дообучаться на ваших действиях.\n")
    else:
        print("\n")
    
    print("Введите ключевые слова (например: 'исследовать лор говорить').")
    print("Команды: 'exit'/'quit'/'q' - выход, 'history' - показать историю, 'reset' - сбросить сессию\n")

    while True:
        raw = input("Ключевые слова игрока> ").strip()
        
        if not raw:
            print("Опишите хотя бы одно ключевое слово взаимодействия.\n")
            continue
        
        if raw.lower() in {"exit", "quit", "q"}:
            print("\n" + "="*60)
            print("📊 ИТОГИ СЕССИИ")
            print("="*60)
            print(f"Всего действий: {session.get_sequence_length()}")
            print(f"Всего предсказаний: {len(session.prediction_history)}")
            if session.prediction_history:
                print(f"Последнее предсказание: {session.prediction_history[-1][0]}")
            print("\nУдачи в ведении игрока!")
            break
        
        if raw.lower() == "history":
            print(f"\n📜 История действий ({session.get_sequence_length()} слов):")
            print(" ".join(session.action_history))
            if session.prediction_history:
                print(f"\n📊 История предсказаний ({len(session.prediction_history)}):")
                for i, (ending, probs) in enumerate(session.prediction_history, 1):
                    print(f"  {i}. {ending} (уверенность: {probs[ending]:.1f}%)")
            print()
            continue
        
        if raw.lower() == "reset":
            session = PlayerSession(initial_threshold=cfg.initial_words_threshold)
            print("✅ Сессия сброшена. История очищена.\n")
            continue

        # Добавляем новые действия к истории
        tokens = raw.split()
        session.add_actions(tokens)
        
        current_length = session.get_sequence_length()
        print(f"📝 Накоплено действий: {current_length} слов")
        
        # Проверяем, достаточно ли данных для предсказания
        if not session.has_enough_data():
            needed = cfg.initial_words_threshold - current_length
            print(f"⏳ Нужно еще {needed} слов для первого предсказания...\n")
            continue
        
        # Делаем предсказание на основе накопленной истории
        try:
            # Используем sliding window, если включен, иначе всю историю
            if cfg.use_sliding_window and cfg.sliding_window_size:
                sequence = session.get_current_sequence(cfg.sliding_window_size)
                window_info = f" (окно: последние {len(sequence)} из {session.get_sequence_length()} действий)"
            else:
                sequence = session.get_current_sequence()
                window_info = f" (вся история: {len(sequence)} действий)"
            
            ending, quests, endings, probs = predict(
                model, vocab, ending_labels, sequence, show_probs=True
            )
            
            # Сохраняем предсказание
            session.save_prediction(ending, probs)
            
            # Проверяем, изменилось ли предсказание
            change_info = session.get_prediction_change()
            
            print("\n" + "-"*60)
            if change_info:
                print(f"🔄 {change_info}")
            else:
                print(f"✅ Предсказание обновлено на основе накопленной истории{window_info}")
            print("-"*60)
            
            print(f"\n🎯 Рекомендуемая ветка: {ending}")
            if probs:
                print("\n📊 Вероятности классов:")
                for class_name, prob in sorted(probs.items(), key=lambda x: x[1], reverse=True):
                    marker = "👈" if class_name == ending else "  "
                    print(f"  {marker} {class_name}: {prob:.1f}%")
            
            print("\n📜 Адаптивные квесты:")
            for quest in quests:
                print(f"  - {quest}")
            
            print("\n🏆 Вероятные концовки:")
            for summary in endings:
                print(f"  - {summary}")
            
            # Опциональное дообучение на новых данных
            if cfg.enable_fine_tuning and len(session.prediction_history) > 1:
                # Используем только последние действия для дообучения
                # Это позволяет модели адаптироваться к новым паттернам
                recent_actions = session.action_history[-8:]  # Последние 8 действий
                if recent_actions and len(recent_actions) >= 3:
                    # Создаем псевдо-пример для демонстрации концепции
                    # В реальной системе здесь были бы реальные данные с метками от игрока
                    pseudo_sample = (" ".join(recent_actions), ending)
                    
                    print(f"\n🔄 Дообучение модели на новых данных...")
                    fine_tune_model(
                        model, vocab,
                        {label: idx for idx, label in enumerate(ending_labels)},
                        [pseudo_sample],
                        epochs=2,  # Уменьшено для меньшего влияния на модель
                        lr=cfg.fine_tuning_lr,
                    )
                    print("✅ Модель обновлена на основе ваших действий!")
            
            print()
            
        except ValueError as err:
            print(f"⚠️  Предупреждение: {err}\n")
            continue


def visualize_training(history: Dict[str, List[float]]) -> None:
    """
    Визуализирует процесс обучения модели.
    Создает графики loss и accuracy по эпохам.
    """
    if plt is None or np is None:
        print("Визуализация недоступна: matplotlib не установлен.")
        return
    
    epochs = history['epochs']
    
    # Создаем фигуру с двумя подграфиками
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))
    
    # График Loss
    ax1.plot(epochs, history['train_loss'], label='Train Loss', linewidth=2)
    if history['val_loss']:
        ax1.plot(epochs, history['val_loss'], label='Validation Loss', linewidth=2)
    ax1.set_xlabel('Эпоха', fontsize=12)
    ax1.set_ylabel('Loss', fontsize=12)
    ax1.set_title('Изменение функции потерь в процессе обучения', fontsize=14, fontweight='bold')
    ax1.legend(fontsize=11)
    ax1.grid(True, alpha=0.3)
    
    # График Accuracy
    ax2.plot(epochs, history['train_acc'], label='Train Accuracy', linewidth=2)
    if history['val_acc']:
        ax2.plot(epochs, history['val_acc'], label='Validation Accuracy', linewidth=2)
    ax2.set_xlabel('Эпоха', fontsize=12)
    ax2.set_ylabel('Accuracy (%)', fontsize=12)
    ax2.set_title('Изменение точности в процессе обучения', fontsize=14, fontweight='bold')
    ax2.legend(fontsize=11)
    ax2.grid(True, alpha=0.3)
    
    plt.tight_layout()
    
    # Сохраняем график
    plt.savefig('training_history.png', dpi=300, bbox_inches='tight')
    print("График обучения сохранен в файл 'training_history.png'")
    
    # Показываем график
    plt.show()


def print_examples_from_test_set(
    model: QuestLSTM,
    vocab: Dict[str, int],
    ending_labels: List[str],
    test_samples: List[Tuple[str, str]],
    test_batch: torch.Tensor,
    test_lengths: torch.Tensor,
    test_labels: torch.Tensor,
    num_examples: int = 10,
) -> None:
    """
    Выводит примеры предсказаний модели на тестовом наборе.
    """
    model.eval()
    
    # Выбираем случайные примеры из тестового набора
    indices = torch.randperm(len(test_samples))[:num_examples]
    
    print("="*80)
    print("ПРИМЕРЫ ПРЕДСКАЗАНИЙ НА ТЕСТОВОМ НАБОРЕ")
    print("="*80)
    print()
    
    correct = 0
    total = 0
    
    with torch.no_grad():
        for i, idx in enumerate(indices, 1):
            idx_int = int(idx)
            text, true_label = test_samples[idx_int]
            
            # Получаем предсказание для этого примера
            batch_item = test_batch[idx_int:idx_int+1]
            length_item = test_lengths[idx_int:idx_int+1]
            label_item = test_labels[idx_int:idx_int+1]
            
            logits = model(batch_item, length_item)
            probs = torch.softmax(logits, dim=-1).squeeze(0)
            pred_idx = int(torch.argmax(probs))
            predicted_label = ending_labels[pred_idx]
            
            # Проверяем правильность
            is_correct = (predicted_label == true_label)
            if is_correct:
                correct += 1
            total += 1
            
            # Выводим результат
            status = "✅ ПРАВИЛЬНО" if is_correct else "❌ ОШИБКА"
            print(f"Пример {i}: {status}")
            print(f"  Входная последовательность: {text}")
            print(f"  Истинная метка: {true_label}")
            print(f"  Предсказанная метка: {predicted_label}")
            print(f"  Вероятности:")
            for j, label in enumerate(ending_labels):
                prob = float(probs[j]) * 100
                marker = "👈" if label == predicted_label else "  "
                print(f"    {marker} {label}: {prob:.1f}%")
            print()
    
    accuracy = (correct / total) * 100 if total > 0 else 0
    print("="*80)
    print(f"Точность на выбранных примерах: {correct}/{total} ({accuracy:.1f}%)")
    print("="*80)
    print()


def main() -> None:
    torch.manual_seed(42)

    # Разделяем данные на train/val/test
    train_samples, val_samples, test_samples = split_dataset(
        PLAYER_SAMPLES, train_ratio=0.7, val_ratio=0.15, seed=42
    )
    
    print(f"Размер датасета: {len(PLAYER_SAMPLES)} примеров")
    print(f"  Train: {len(train_samples)} примеров")
    print(f"  Val: {len(val_samples)} примеров")
    print(f"  Test: {len(test_samples)} примеров")
    print()

    # Строим словарь на всех данных для консистентности
    vocab = build_vocab(PLAYER_SAMPLES)
    endings = sorted({label for _, label in PLAYER_SAMPLES})
    label_to_idx = {label: idx for idx, label in enumerate(endings)}

    # Кодируем разделенные данные
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

    print("Обучение LSTM...")
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
    print("Обучение завершено.\n")

    # Оценка на тестовом наборе
    print("Оценка на тестовом наборе:")
    test_loss, test_acc = evaluate_model(model, test_batch, test_lengths, test_labels)
    print(f"  Test ошибка: {test_loss:.4f}")
    print(f"  Test точность: {test_acc:.1f}%\n")

    # Визуализация процесса обучения
    if plt is not None:
        visualize_training(history)
    
    # Примеры предсказаний на тестовом наборе
    print_examples_from_test_set(
        model, vocab, endings, test_samples, test_batch, test_lengths, test_labels, num_examples=10
    )


if __name__ == "__main__":
    main()
    input()

