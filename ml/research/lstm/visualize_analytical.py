"""
Рисунки для аналитической части и архитектуры (глава 1, 3, 6).

Запуск:
    py -3 visualize_analytical.py

Выход: docs/diagrams/fig_1_* ... fig_3_* ... fig_6_7_*
"""

from __future__ import annotations

from pathlib import Path

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, Circle

OUTPUT_DIR = Path(__file__).resolve().parents[3] / "docs" / "diagrams"

plt.rcParams.update(
    {
        "font.sans-serif": ["Segoe UI", "Arial", "DejaVu Sans"],
        "axes.unicode_minus": False,
        "figure.dpi": 120,
        "savefig.dpi": 300,
    }
)

# Параметры адаптации из ml/predictor.py
ADAPTATION = {
    "explorer": {"difficulty": 0.85, "enemy_density": 0.9, "loot_multiplier": 1.2},
    "achiever": {"difficulty": 1.2, "enemy_density": 1.1, "loot_multiplier": 1.0},
    "socializer": {"difficulty": 0.95, "enemy_density": 0.85, "loot_multiplier": 1.15},
    "killer": {"difficulty": 1.35, "enemy_density": 1.4, "loot_multiplier": 0.95},
}

# Качественная оценка 0–5 по критериям (источник: табл. 1.1 + открытые описания продуктов)
SOLUTIONS = ["Unity\nAnalytics", "Game\nAnalytics", "Left 4 Dead\nAI Director", "Ручная\nразработка", "DiplicsTM\n(проект)"]
CRITERIA = ["Адаптация\nв реальном\nвремени", "ML /\nобучаемость", "Переносимость\nмежду играми", "Интеграция\nв движок", "Offline-\nустойчивость"]
SCORES = np.array(
    [
        [0, 0, 5, 3, 0],  # Unity Analytics
        [0, 0, 5, 2, 0],  # GameAnalytics
        [5, 0, 0, 1, 0],  # L4D Director
        [5, 2, 0, 2, 0],  # Manual
        [5, 5, 5, 5, 4],  # DiplicsTM
    ]
)


def plot_bartle_quadrant(out: Path) -> None:
    fig, ax = plt.subplots(figsize=(8, 8))
    ax.set_xlim(-1.2, 1.2)
    ax.set_ylim(-1.2, 1.2)
    ax.axhline(0, color="#94a3b8", lw=1)
    ax.axvline(0, color="#94a3b8", lw=1)
    ax.set_xlabel("Действие  ←  →  Взаимодействие")
    ax.set_ylabel("Мир игры  ←  →  Другие игроки")
    ax.set_title("Классификация архетипов игроков (Bartle, 1996)")

    archetypes = [
        (0.55, 0.55, "Explorer\n(исследователь)", "#3b82f6"),
        (0.55, -0.55, "Achiever\n(достигатель)", "#059669"),
        (-0.55, 0.55, "Socializer\n(социализатор)", "#f59e0b"),
        (-0.55, -0.55, "Killer\n(убийца)", "#dc2626"),
    ]
    for x, y, label, color in archetypes:
        ax.add_patch(Circle((x, y), 0.35, facecolor=color, alpha=0.25, edgecolor=color, lw=2))
        ax.text(x, y, label, ha="center", va="center", fontsize=11, fontweight="bold")

    ax.text(0, -1.05, "Источник: R. Bartle — Hearts, Clubs, Diamonds, Spades (1996)", ha="center", fontsize=9, color="#64748b")
    ax.set_aspect("equal")
    ax.axis("off")
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_solutions_heatmap(out: Path) -> None:
    fig, ax = plt.subplots(figsize=(11, 6))
    im = ax.imshow(SCORES, cmap="YlGn", vmin=0, vmax=5, aspect="auto")
    ax.set_xticks(range(len(CRITERIA)))
    ax.set_yticks(range(len(SOLUTIONS)))
    ax.set_xticklabels(CRITERIA, fontsize=9)
    ax.set_yticklabels(SOLUTIONS, fontsize=10)
    ax.set_title("Сравнение существующих решений по критериям (табл. 1.1, расширенная шкала 0–5)")

    for i in range(len(SOLUTIONS)):
        for j in range(len(CRITERIA)):
            val = int(SCORES[i, j])
            color = "white" if val >= 3 else "black"
            ax.text(j, i, str(val), ha="center", va="center", color=color, fontsize=11, fontweight="bold")

    cbar = fig.colorbar(im, ax=ax, fraction=0.03)
    cbar.set_label("Оценка (0 — нет, 5 — полностью)")
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_literature_metrics(out: Path) -> None:
    """Метрики из описаний известных работ (качественные, для аналитической части)."""
    works = [
        "Bartle\n(1996)",
        "L4D AI\nDirector\n(Valve)",
        "Yannakakis\n& Togelius\n(2011)",
        "Unity\nAnalytics",
        "DiplicsTM\n(наш проект)",
    ]
    # Шкала 0–100: экспертная оценка по литературе / документации
    real_time = [20, 95, 40, 5, 90]
    personalization = [60, 70, 55, 15, 85]
    portability = [90, 5, 30, 80, 85]

    x = np.arange(len(works))
    w = 0.25
    fig, ax = plt.subplots(figsize=(12, 6))
    ax.bar(x - w, real_time, w, label="Адаптация в реальном времени", color="#2563eb")
    ax.bar(x, personalization, w, label="Персонализация опыта", color="#059669")
    ax.bar(x + w, portability, w, label="Переносимость решения", color="#7c3aed")
    ax.set_ylabel("Экспертная оценка, %")
    ax.set_ylim(0, 105)
    ax.set_xticks(x)
    ax.set_xticklabels(works, fontsize=9)
    ax.set_title("Сравнительные метрики подходов (по данным литературы и документации)")
    ax.legend(loc="upper right", fontsize=9)
    ax.grid(True, axis="y", alpha=0.3)
    ax.text(
        0.5,
        -0.18,
        "Примечание: оценки нормированы для сравнительного анализа; "
        "источники: Bartle (1996), Booth (GDC 2009), Yannakakis & Togelius (2011), Unity Docs.",
        transform=ax.transAxes,
        ha="center",
        fontsize=8,
        color="#64748b",
    )
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_system_architecture(out: Path) -> None:
    fig, ax = plt.subplots(figsize=(14, 7))
    ax.set_xlim(0, 14)
    ax.set_ylim(0, 8)
    ax.axis("off")
    ax.set_title("Архитектура системы DiplicsTM (общий проект)", fontsize=14, fontweight="bold")

    layers = [
        (1.0, 5.5, 4.5, 1.8, "Godot 4 + analytics_plugin\n:8000 клиент", "#dbeafe", "HTTP JSON"),
        (6.0, 5.5, 4.5, 1.8, "Backend FastAPI\nPOST /telemetry/ingest\n:8000", "#fef3c7", "HTTP"),
        (11.0, 5.5, 2.5, 1.8, "ML-сервис\nPOST /predict\n:8001", "#dcfce7", ""),
        (6.0, 2.0, 4.5, 1.8, "PostgreSQL :5432\nplayers · sessions · events · predictions", "#f3e8ff", "SQL"),
        (11.0, 2.0, 2.5, 1.8, "ONNX Runtime\nclassifier.onnx", "#fce7f3", ""),
    ]

    for x, y, w, h, text, color, _ in layers:
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.08", facecolor=color, edgecolor="#334155", lw=1.5))
        ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=9)

    arrows = [
        ((5.5, 6.4), (6.0, 6.4), "телеметрия"),
        ((10.5, 6.4), (11.0, 6.4), "features / seq"),
        ((8.25, 5.5), (8.25, 3.8), "запись"),
        ((12.25, 5.5), (12.25, 3.8), ""),
        ((8.25, 2.0), (5.5, 6.0), "train data"),
    ]
    for (x0, y0), (x1, y1), label in arrows:
        ax.add_patch(FancyArrowPatch((x0, y0), (x1, y1), arrowstyle="-|>", mutation_scale=12, color="#475569", lw=1.2))
        if label:
            ax.text((x0 + x1) / 2, (y0 + y1) / 2 + 0.15, label, ha="center", fontsize=8, color="#b45309")

    ax.text(7, 0.5, "Docker Compose: postgres + backend + ml", ha="center", fontsize=10, color="#64748b")
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_data_flow(out: Path) -> None:
    steps = [
        "1. track(event)",
        "2. Буфер\nGodot",
        "3. POST\n/ingest",
        "4. PostgreSQL",
        "5. Кодирование\nпоследовательности",
        "6. POST\n/predict",
        "7. LSTM\nONNX",
        "8. adaptation\n→ Godot",
    ]
    fig, ax = plt.subplots(figsize=(14, 3))
    ax.set_xlim(0, len(steps))
    ax.set_ylim(0, 2)
    ax.axis("off")
    ax.set_title("Поток данных: от действия игрока до адаптации")

    for i, label in enumerate(steps):
        color = "#dbeafe" if i % 2 == 0 else "#ecfdf5"
        ax.add_patch(FancyBboxPatch((i + 0.05, 0.5), 0.85, 1.0, boxstyle="round,pad=0.05", facecolor=color, edgecolor="#1e40af"))
        ax.text(i + 0.475, 1.0, label, ha="center", va="center", fontsize=8)
        if i < len(steps) - 1:
            ax.annotate("", xy=(i + 1.05, 1.0), xytext=(i + 0.92, 1.0), arrowprops=dict(arrowstyle="-|>", color="#475569"))

    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_db_schema(out: Path) -> None:
    tables = {
        "players": (1, 5, ["player_id PK", "created_at"]),
        "game_models": (5, 5, ["model_id PK", "model_version", "critical_points", "archetypes"]),
        "sessions": (1, 2.5, ["session_id PK", "player_id FK", "model_id FK"]),
        "events": (5, 2.5, ["event_id PK", "session_id FK", "event_type", "payload"]),
        "predictions": (9, 3.75, ["prediction_id PK", "session_id FK", "predicted_archetype", "confidence"]),
    }
    fig, ax = plt.subplots(figsize=(12, 7))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 7)
    ax.axis("off")
    ax.set_title("Логическая схема базы данных PostgreSQL")

    for name, (x, y, cols) in tables.items():
        h = 0.35 + 0.35 * len(cols)
        ax.add_patch(FancyBboxPatch((x, y), 2.8, h, boxstyle="square,pad=0.02", facecolor="#f8fafc", edgecolor="#334155"))
        ax.text(x + 1.4, y + h - 0.2, name, ha="center", fontweight="bold", fontsize=10)
        for j, col in enumerate(cols):
            ax.text(x + 0.15, y + h - 0.55 - j * 0.35, col, fontsize=8)

    fk_arrows = [
        ((2.8, 3.2), (5.0, 3.2)),
        ((2.8, 2.8), (5.0, 2.8)),
        ((7.8, 2.8), (9.0, 3.5)),
        ((7.8, 3.2), (9.0, 3.9)),
    ]
    for (x0, y0), (x1, y1) in fk_arrows:
        ax.add_patch(FancyArrowPatch((x0, y0), (x1, y1), arrowstyle="-|>", mutation_scale=10, color="#94a3b8", linestyle="--"))

    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_adaptation_params(out: Path) -> None:
    archetypes = list(ADAPTATION.keys())
    labels_ru = ["Исследователь", "Достигатель", "Социализатор", "Убийца"]
    params = ["difficulty", "enemy_density", "loot_multiplier"]
    titles = ["Сложность", "Плотность врагов", "Множитель лута"]
    colors = ["#3b82f6", "#059669", "#f59e0b", "#dc2626"]

    fig, axes = plt.subplots(1, 3, figsize=(14, 5))
    x = np.arange(len(archetypes))

    for ax, param, title in zip(axes, params, titles):
        vals = [ADAPTATION[a][param] for a in archetypes]
        bars = ax.bar(x, vals, color=colors)
        ax.axhline(1.0, color="#94a3b8", linestyle="--", lw=1, label="Базовый уровень (1.0)")
        ax.set_xticks(x)
        ax.set_xticklabels(labels_ru, rotation=15, ha="right", fontsize=9)
        ax.set_ylabel("Множитель")
        ax.set_title(title)
        ax.set_ylim(0.7, 1.5)
        ax.grid(True, axis="y", alpha=0.3)
        for bar, v in zip(bars, vals):
            ax.text(bar.get_x() + bar.get_width() / 2, v + 0.02, f"{v:.2f}", ha="center", fontsize=9)

    fig.suptitle("Параметры адаптации по архетипам (§6.1)", fontsize=13, fontweight="bold")
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_lstm_vs_rf_radar(out: Path) -> None:
    categories = [
        "Учёт\nпоследовательности",
        "Скорость\nинференса",
        "Интерпретиру-\nемость",
        "Точность\n(наш exp.)",
        "Переобучение\nна данных",
        "Переносимость\n(ONNX)",
    ]
    lstm = [5, 4, 2, 4.8, 5, 5]  # 4.8 ≈ 95.59%
    rf = [1, 5, 5, 5.0, 4, 5]

    angles = np.linspace(0, 2 * np.pi, len(categories), endpoint=False).tolist()
    lstm += lstm[:1]
    rf += rf[:1]
    angles += angles[:1]

    fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(polar=True))
    ax.plot(angles, lstm, "o-", lw=2, label="LSTM (QuestLSTM)", color="#2563eb")
    ax.fill(angles, lstm, alpha=0.15, color="#2563eb")
    ax.plot(angles, rf, "o-", lw=2, label="Random Forest (baseline)", color="#dc2626")
    ax.fill(angles, rf, alpha=0.1, color="#dc2626")
    ax.set_xticks(angles[:-1])
    ax.set_xticklabels(categories, fontsize=9)
    ax.set_ylim(0, 5.5)
    ax.set_title("Сравнение LSTM и Random Forest (табл. 4.2)", pad=20, fontweight="bold")
    ax.legend(loc="upper right", bbox_to_anchor=(1.25, 1.1))
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    figures = [
        ("fig_1_1_bartle_quadrant.png", plot_bartle_quadrant),
        ("fig_1_2_solutions_heatmap.png", plot_solutions_heatmap),
        ("fig_1_3_literature_metrics.png", plot_literature_metrics),
        ("fig_3_1_system_architecture.png", plot_system_architecture),
        ("fig_3_2_data_flow.png", plot_data_flow),
        ("fig_3_3_db_schema.png", plot_db_schema),
        ("fig_4_4_lstm_vs_rf_radar.png", plot_lstm_vs_rf_radar),
        ("fig_6_7_adaptation_params.png", plot_adaptation_params),
    ]
    for name, fn in figures:
        path = OUTPUT_DIR / name
        fn(path)
        print(f"  -> {path}")


if __name__ == "__main__":
    main()
