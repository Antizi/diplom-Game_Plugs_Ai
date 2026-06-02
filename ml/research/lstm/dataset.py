"""
Модуль для работы с датасетом игровых стилей.

Содержит:
- Расширенный датасет с 300 примерами на класс
- Функцию разделения данных на train/val/test
"""

from __future__ import annotations

import random
from typing import List, Tuple

# Базовые примеры для каждого класса
SAGE_KEYWORDS = [
    "исследовать", "наблюдать", "лор", "говорить", "расследовать",
    "изучать", "расшифровать", "артефакт", "медитировать", "анализировать",
    "торговать", "договариваться", "помогать", "сопровождать", "создавать",
    "читать", "познавать", "изучать", "размышлять", "понимать",
    "обучать", "наставлять", "советовать", "объяснять", "переводить",
    "собирать", "каталогизировать", "архивировать", "записывать", "документировать",
    "дипломатия", "переговоры", "компромисс", "мир", "соглашение",
    "мудрость", "знание", "история", "хроника", "летопись",
    "магия", "заклинание", "ритуал", "церемония", "обряд",
    "библиотека", "архив", "хранилище", "собрание", "коллекция",
]

SHADOW_KEYWORDS = [
    "красться", "прятаться", "кинжалы", "яд", "тень",
    "стелс", "удар в спину", "исчезать", "шептать",
    "выслеживать", "разведывать", "лук", "ловушка", "тишина",
    "скрытность", "незаметность", "маскировка", "обман", "хитрость",
    "убийство", "ликвидация", "устранение", "нейтрализация", "ликвидация",
    "шпионаж", "разведка", "информация", "секрет", "тайна",
    "взлом", "проникновение", "обход", "обман", "подлог",
    "ночь", "тьма", "мрак", "сумерки", "полумрак",
    "тишина", "бесшумность", "скрытность", "незаметность", "осторожность",
    "ловкость", "проворство", "быстрота", "резкость", "точность",
]
#Использование рекуррентных нейронных сетей типа 
# LSTM для адаптации игрового контента на основе анализа временных последовательностей действий игрока
WARLORD_KEYWORDS = [
    "рывок", "удар", "щит", "дуэль", "рев",
    "арена", "ярость", "сокрушать", "запугивать", "вести",
    "вызов", "честь", "знамя", "защищать", "сплачивать",
    "битва", "сражение", "война", "атака", "штурм",
    "сила", "мощь", "власть", "доминирование", "превосходство",
    "лидерство", "команда", "отряд", "армия", "войско",
    "оружие", "меч", "копье", "топор", "булава",
    "доспех", "броня", "защита", "щит", "шлем",
    "стратегия", "тактика", "план", "маневр", "операция",
    "победа", "триумф", "завоевание", "покорение", "господство",
]


def generate_mixed_examples(
    examples_per_combination: int = 50,
    seed: int = 42,
) -> List[Tuple[str, str]]:
    """
    Генерирует примеры со смешанными ключевыми словами из разных классов.
    Доминирующий класс определяется по количеству ключевых слов.
    
    Args:
        examples_per_combination: Количество примеров для каждой комбинации классов
        seed: Seed для воспроизводимости
        
    Returns:
        Список кортежей (ключевые слова, метка класса)
    """
    random.seed(seed)
    dataset: List[Tuple[str, str]] = []
    
    all_keywords = {
        "sage_path": SAGE_KEYWORDS,
        "shadow_path": SHADOW_KEYWORDS,
        "warlord_path": WARLORD_KEYWORDS,
    }
    
    classes = list(all_keywords.keys())
    
    # Генерируем смешанные примеры для каждой пары классов
    for i, dominant_class in enumerate(classes):
        for other_class in classes[i+1:]:
            # Примеры, где dominant_class доминирует (60-80% слов)
            for _ in range(examples_per_combination):
                total_words = random.randint(5, 10)
                dominant_count = random.randint(
                    int(total_words * 0.6),
                    int(total_words * 0.8)
                )
                other_count = total_words - dominant_count
                
                dominant_words = random.sample(
                    all_keywords[dominant_class], 
                    min(dominant_count, len(all_keywords[dominant_class]))
                )
                other_words = random.sample(
                    all_keywords[other_class],
                    min(other_count, len(all_keywords[other_class]))
                )
                
                # Перемешиваем слова для реалистичности
                all_words = dominant_words + other_words
                random.shuffle(all_words)
                dataset.append((" ".join(all_words), dominant_class))
            
            # Примеры, где other_class доминирует
            for _ in range(examples_per_combination):
                total_words = random.randint(5, 10)
                dominant_count = random.randint(
                    int(total_words * 0.6),
                    int(total_words * 0.8)
                )
                other_count = total_words - dominant_count
                
                dominant_words = random.sample(
                    all_keywords[other_class],
                    min(dominant_count, len(all_keywords[other_class]))
                )
                other_words = random.sample(
                    all_keywords[dominant_class],
                    min(other_count, len(all_keywords[dominant_class]))
                )
                
                all_words = dominant_words + other_words
                random.shuffle(all_words)
                dataset.append((" ".join(all_words), other_class))
    
    # Трехклассовые смеси (где один класс явно доминирует)
    for dominant_class in classes:
        other_classes = [c for c in classes if c != dominant_class]
        for _ in range(examples_per_combination):
            total_words = random.randint(6, 12)
            dominant_count = random.randint(
                int(total_words * 0.5),
                int(total_words * 0.7)
            )
            remaining = total_words - dominant_count
            other1_count = remaining // 2
            other2_count = remaining - other1_count
            
            dominant_words = random.sample(
                all_keywords[dominant_class],
                min(dominant_count, len(all_keywords[dominant_class]))
            )
            other1_words = random.sample(
                all_keywords[other_classes[0]],
                min(other1_count, len(all_keywords[other_classes[0]]))
            )
            other2_words = random.sample(
                all_keywords[other_classes[1]],
                min(other2_count, len(all_keywords[other_classes[1]]))
            )
            
            all_words = dominant_words + other1_words + other2_words
            random.shuffle(all_words)
            dataset.append((" ".join(all_words), dominant_class))
    
    return dataset


def generate_dataset(examples_per_class: int = 300, seed: int = 42) -> List[Tuple[str, str]]:
    """
    Генерирует расширенный датасет с указанным количеством примеров на класс.
    Включает как чистые примеры, так и смешанные.
    
    Args:
        examples_per_class: Количество чистых примеров для каждого класса
        seed: Seed для воспроизводимости
        
    Returns:
        Список кортежей (ключевые слова, метка класса)
    """
    random.seed(seed)
    dataset: List[Tuple[str, str]] = []
    
    # Генерируем чистые примеры для sage_path
    for _ in range(examples_per_class):
        num_keywords = random.randint(3, 7)
        keywords = random.sample(SAGE_KEYWORDS, num_keywords)
        dataset.append((" ".join(keywords), "sage_path"))
    
    # Генерируем чистые примеры для shadow_path
    for _ in range(examples_per_class):
        num_keywords = random.randint(3, 7)
        keywords = random.sample(SHADOW_KEYWORDS, num_keywords)
        dataset.append((" ".join(keywords), "shadow_path"))
    
    # Генерируем чистые примеры для warlord_path
    for _ in range(examples_per_class):
        num_keywords = random.randint(3, 7)
        keywords = random.sample(WARLORD_KEYWORDS, num_keywords)
        dataset.append((" ".join(keywords), "warlord_path"))
    
    # Добавляем смешанные примеры для лучшей генерализации
    mixed_examples = generate_mixed_examples(examples_per_combination=50, seed=seed)
    dataset.extend(mixed_examples)
    
    # Перемешиваем датасет
    random.shuffle(dataset)
    return dataset


def split_dataset(
    samples: List[Tuple[str, str]],
    train_ratio: float = 0.7,
    val_ratio: float = 0.15,
    seed: int = 42,
) -> Tuple[List[Tuple[str, str]], List[Tuple[str, str]], List[Tuple[str, str]]]:
    """
    Разделяет датасет на train/val/test с сохранением пропорций классов.
    
    Args:
        samples: Список примеров (ключевые слова, метка)
        train_ratio: Доля обучающей выборки (по умолчанию 0.7)
        val_ratio: Доля валидационной выборки (по умолчанию 0.15)
        seed: Seed для воспроизводимости
        
    Returns:
        Кортеж (train_samples, val_samples, test_samples)
    """
    random.seed(seed)
    
    # Группируем по классам для стратифицированного разделения
    class_samples: dict[str, List[Tuple[str, str]]] = {}
    for sample in samples:
        label = sample[1]
        if label not in class_samples:
            class_samples[label] = []
        class_samples[label].append(sample)
    
    train_samples: List[Tuple[str, str]] = []
    val_samples: List[Tuple[str, str]] = []
    test_samples: List[Tuple[str, str]] = []
    
    test_ratio = 1.0 - train_ratio - val_ratio
    
    # Разделяем каждый класс отдельно
    for label, class_data in class_samples.items():
        random.shuffle(class_data)
        n = len(class_data)
        
        train_end = int(n * train_ratio)
        val_end = train_end + int(n * val_ratio)
        
        train_samples.extend(class_data[:train_end])
        val_samples.extend(class_data[train_end:val_end])
        test_samples.extend(class_data[val_end:])
    
    # Перемешиваем финальные выборки
    random.shuffle(train_samples)
    random.shuffle(val_samples)
    random.shuffle(test_samples)
    
    return train_samples, val_samples, test_samples


# Генерируем датасет по умолчанию (300 примеров на класс)
PLAYER_SAMPLES = generate_dataset(examples_per_class=300, seed=42)

