# Концепция: Визуализация кода в виде диаграмм (v3)

## Содержание

- [1. Узел (Node)](#1-узел-node)
  - [1.1. Типы узлов (6 типов)](#11-типы-узлов-6-типов)
- [2. Коннект (Connection)](#2-коннект-connection)
  - [2.1. Принцип](#21-принцип)
  - [2.2. Расположение коннектов](#22-расположение-коннектов)
  - [2.3. Коннекторы есть у всех сворачиваемых узлов](#23-коннекторы-есть-у-всех-сворачиваемых-узлов)
  - [2.4. Тип коннектора по type (по умолчанию)](#24-тип-коннектора-по-type-по-умолчанию)
  - [2.5. Визуал коннектов](#25-визуал-коннектов)
- [3. Вложенность и раскрытие (Level)](#3-вложенность-и-раскрытие-level)
  - [3.1. Принцип](#31-принцип)
  - [3.2. Перенос связей при раскрытии](#32-перенос-связей-при-раскрытии)
  - [3.3. Уровни детализации (пример)](#33-уровни-детализации-пример)
- [4. Универсальный узел (UniversalNode)](#4-универсальный-узел-universalnode)
  - [4.1. Компоненты узла](#41-компоненты-узла)
  - [4.2. Конфигурация компонентов по type](#42-конфигурация-компонентов-по-type)
  - [4.3. Визуальные примеры по type](#43-визуальные-примеры-по-type)
  - [4.4. Палитра по stereotype](#44-палитра-по-stereotype)
  - [4.5. Общие стили](#45-общие-стили)
- [5. Модификаторы узлов](#5-модификаторы-узлов)
  - [5.1. Модификаторы доступа](#51-модификаторы-доступа)
  - [5.2. Модификаторы поведения](#52-модификаторы-поведения)
  - [5.3. Комбинации](#53-комбинации)
- [6. Связь (Arrow)](#6-связь-arrow)
  - [6.1. Типы связей (5 типов)](#61-типы-связей-5-типов)
  - [6.2. Оформление концов связей](#62-оформление-концов-связей)
  - [6.3. Оформление линий](#63-оформление-линий)
  - [6.4. Оформление середины связи (опционально)](#64-оформление-середины-связи-опционально)
  - [6.5. Подтип связи](#65-подтип-связи)
- [7. Заметки (Notes)](#7-заметки-notes)
  - [7.1. Структура notes[]](#71-структура-notes)
  - [7.2. Типы заметок и отображение](#72-типы-заметок-и-отображение)
  - [7.3. Tooltip](#73-tooltip)
  - [7.4. Бейджи заметок](#74-бейджи-заметок)
- [8. Легенда](#8-легенда)
- [9. JSON-структура](#9-json-структура)
  - [9.1. Узел (block)](#91-узел-block)
  - [9.2. Связь (arrow)](#92-связь-arrow)
- [10. Настройки стилей (Style Config)](#10-настройки-стилей-style-config)
  - [10.1. Структура файла](#101-структура-файла)
  - [10.2. Глобальные настройки (global)](#102-глобальные-настройки-global)
  - [10.3. Настройки узлов (nodes)](#103-настройки-узлов-nodes)
  - [10.4. Настройки связей (arrows)](#104-настройки-связей-arrows)
  - [10.5. Настройки коннекторов (connectors)](#105-настройки-коннекторов-connectors)
  - [10.6. Настройки модификаторов (modifiers)](#106-настройки-модификаторов-modifiers)
  - [10.7. Пример полного файла настроек (минимальный)](#107-пример-полного-файла-настроек-минимальный)
  - [10.8. Правила применения](#108-правила-применения)

---

## 1. Узел (Node). 

### 1.1. Типы узлов (6 типов)

| type | Назначение | Содержит атрибуты | Содержит children | Раскрывается |
|---|---|---|---|---|
| `group` | Контейнер (модуль, пакет, файл, namespace, scope) | Нет | Да | Да |
| `block` | Структурное определение (class, interface, enum, struct, type, mixin, abstract) | Да | Да | Да |
| `func` | Исполняемый элемент (function, method, constructor, getter, setter, lambda) | Да (аргументы) | Да (тело) | Да |
| `value` | Хранилище данных (variable, constant, field, property) | Опционально | Да (если сложный объект) | Да |
| `ref` | Внешняя ссылка (import, export, dependency, library) | Нет | Нет | Нет |
| `meta` | Метаданные (decorator, annotation, pragma, directive, legend) | Опционально (параметры) | Нет | Нет |

Заметки (TODO, FIXME, doc) хранятся в поле `notes[]` любого узла (см. [раздел 7](#7-заметки-notes)).

**Конкретный подтип** определяется полем `stereotype`, а не отдельным type:

| type | stereotype | Языки |
|---|---|---|
| `group` | `"module"` | JS/TS, Python, Dart, Go |
| | `"package"` | Java, Kotlin, Go, Dart |
| | `"file"` | Все |
| | `"namespace"` | C#, C++, TS, PHP |
| | `"scope"` | Все (блок `{}`) |
| | `"region"` | C#, C++ (`#region`) |
| | `"crate"` | Rust |
| `block` | `"class"` | JS/TS, Java, Python, Dart, Kotlin, C#, C++, Swift, Ruby |
| | `"abstract"` | Java, Dart, Kotlin, C#, C++ |
| | `"interface"` | TS, Java, Dart, Kotlin, C#, Go |
| | `"enum"` | Все |
| | `"struct"` | Go, Rust, C#, Swift, C/C++, Dart (record) |
| | `"type"` | TS, Go (`type`), Rust (`type`), Swift (`typealias`) |
| | `"mixin"` | Dart, Ruby, Python (множественное наследование) |
| | `"record"` | Java, Kotlin (`data class`), C# |
| | `"trait"` | Rust, PHP, Scala |
| | `"protocol"` | Swift, Objective-C |
| | `"extension"` | Dart, Swift, Kotlin, C# |
| | `"impl"` | Rust (`impl Block`) |
| | `"object"` | Kotlin (`object` / `companion object`), Scala |
| | `"sealed"` | Kotlin, Java, Dart |
| | `"union"` | C/C++, Rust (`enum`-union), TS (union type) |
| | `"delegate"` | C#, Kotlin |
| | `"template"` | C++ (`template<>`) |
| `func` | `"function"` | Все |
| | `"method"` | Все (метод класса) |
| | `"constructor"` | Все |
| | `"destructor"` | C++, Rust (`drop`), Python (`__del__`) |
| | `"getter"` | JS/TS, Dart, Kotlin, C# |
| | `"setter"` | JS/TS, Dart, Kotlin, C# |
| | `"lambda"` | Все (анонимная функция, closure) |
| | `"operator"` | Kotlin, Dart, C++, Python (`__add__`), Rust |
| | `"generator"` | JS/TS, Python (`yield`), Dart (`sync*`/`async*`) |
| | `"coroutine"` | Kotlin (`suspend`), Python (`async def`), Go (goroutine) |
| `value` | `"variable"` | Все (`let`, `var`, `:=`) |
| | `"constant"` | Все (`const`, `final`, `val`) |
| | `"field"` | Все (поле класса/структуры) |
| | `"property"` | Kotlin, C#, Swift, TS |
| | `"param"` | Все (параметр функции) |
| | `"channel"` | Go (`chan`), Dart (`StreamController`) |
| | `"event"` | C# (`event`), Dart (`Stream`) |
| | `"signal"` | Dart (Signals), JS (Solid.js, Angular Signals) |
| `ref` | `"import"` | Все |
| | `"export"` | JS/TS, Dart |
| | `"dependency"` | Все (внешняя зависимость) |
| | `"require"` | Node.js (CommonJS), PHP |
| | `"include"` | C/C++ (`#include`), PHP |
| | `"use"` | Rust, Go, PHP |
| `meta` | `"decorator"` | TS, Python, Dart (planned) |
| | `"annotation"` | Java, Kotlin, Dart |
| | `"pragma"` | C/C++ (`#pragma`), Dart |
| | `"macro"` | Rust (`macro_rules!`), C/C++ (`#define`) |
| | `"attribute"` | C# (`[Attribute]`), Rust (`#[attr]`) |
| | `"legend"` | Все (легенда диаграммы) |

---

## 2. Коннект (Connection)

### 2.1. Принцип

Каждый узел имеет **4 коннекта** (top, right, bottom, left) — по одной точке на каждой стороне.
Каждый атрибут имеет **2 коннекта** (left, right) — по одной точке на каждой стороне.

**Все коннекты узла/атрибута имеют один и тот же тип** — `in`, `out` или `inout`. Тип задаётся **один раз** для всего узла/атрибута, а не для каждой стороны отдельно.

Причина: алгоритм рисования связей **динамически выбирает ближайший коннект** для подключения в зависимости от взаимного расположения узлов на канвасе. Связь прикрепляется к той точке, которая ближе к связанному элементу.

### 2.2. Расположение коннектов

**Left и Right** — по центру **заголовка** узла (на уровне середины header по вертикали).
**Top и Bottom** — по центру **ширины** узла.

```
                  ● top
         ┌────────┼──────────────┐
      ●──│  «class» AuthService  │──●
    left │                       │ right
         ├───────────────────────┤
         │  атрибуты / children  │
         └────────┼──────────────┘
                  ● bottom
```

Атрибуты — left и right по центру высоты строки:

```
         ┌──────────────────────┐
      ●──│   attribute row      │──●
    left └──────────────────────┘ right
```

### 2.3. Коннекторы есть у всех сворачиваемых узлов

Коннекторы присутствуют у **всех 6 типов** узлов. При **сворачивании** связи вложенных элементов переносятся на родительский узел.

| type | Коннекторы | Причина |
|---|---|---|
| `group` | ● 4 точки | Сворачивается → принимает связи children |
| `block` | ● 4 точки | Сворачивается → принимает связи children |
| `func` | ● 4 точки | Сворачивается → принимает связи children |
| `value` | ● 4 точки | Может сворачиваться (сложный объект) |
| `ref` | ● 4 точки | Связи подключаются |
| `meta` | ● 4 точки | Связи подключаются |

### 2.4. Тип коннектора по type (по умолчанию)

| type | connectionType | Описание |
|---|---|---|
| `group` | `inout` | Контейнер — транзитные связи в обе стороны |
| `block` | `inout` | Класс — принимает и отдаёт зависимости |
| `func` | `inout` | Функция — принимает аргументы, отдаёт результат |
| `value` | `inout` | Переменная — читается и записывается |
| `ref` | `out` | Импорт — только предоставляет зависимости |
| `meta` | `out` | Декоратор — только прикрепляется к целям |

Значение по умолчанию **может быть переопределено** в JSON конкретного узла.

```json
"connectionType": "inout"
```

Допустимые значения: `"in"` | `"out"` | `"inout"` | `"none"`

### 2.5. Визуал коннектов

| Тип | Цвет точки | Обводка | Форма |
|---|---|---|---|
| `in` | `#4CAF50` зелёный | — | ● заполненный круг |
| `out` | `#F44336` красный | — | ● заполненный круг |
| `inout` | `#FFFFFF` белый | `#888` серая, 1px | ○ круг с обводкой |
| `none` | — | — | не отображается |

Размер точки: 6px (обычный), 10px (hover).

---

## 3. Вложенность и раскрытие (Level)

### 3.1. Принцип

Любой узел с `children` может быть **свёрнут** или **развёрнут**. Количество уровней вложенности **неограничено**.

```
Репозиторий
  └─ group (module)
       └─ group (file)
            └─ block (class)
                 ├─ func (constructor)
                 ├─ func (method)
                 │    └─ func (inner function)
                 └─ block (inner class)
                      └─ func (method)
```

### 3.2. Перенос связей при раскрытии

Когда узел **свёрнут** — Shadow скрыта, все связи подключены к родительскому узлу.
Когда узел **раскрыт** — Shadow видна, связи **переносятся** на вложенные узлы, к которым они фактически направлены.

```
СВЁРНУТО:                          РАЗВЁРНУТО:

  ┌─ HttpClient ─┐                   ┌─ HttpClient ─┐
  └──────┬───────┘                   └──────┬───────┘
         │ depend                            │ depend
         ▼                                   │
  ┌─ AuthService [+] ┐               ┌─ AuthService [−] ─────────────┐
  └───────────────────┘               ╎         │                      ╎
                                      ╎         ▼                      ╎
                                      ╎  ┌─ constructor ──────┐        ╎
                                      ╎  │ ● http: HttpClient │        ╎
                                      ╎  └────────────────────┘        ╎
                                      └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

### 3.3. Уровни детализации (пример)

**L0** — Модули свёрнуты:
```
┌─[+] auth ─┐    ──depend──▶    ┌─[+] core ─┐
└────────────┘                   └────────────┘
```

**L1** — Модули раскрыты, классы свёрнуты:
```
┌─[−] auth ─────────────────┐
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
╎  ┌── AuthService [+] ──────┐           ╎
╎  │ login()                  │           ╎
╎  │ logout()                 │           ╎
╎  └──────────────────────────┘           ╎
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

**L2** — Классы раскрыты:
```
┌─[−] auth ─────────────────┐
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
╎  ┌─ AuthService [−] ──────────┐                    ╎
╎  ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐         ╎
╎  ╎  ┌─ constructor ────────┐             ╎         ╎
╎  ╎  │ ● http: HttpClient   │             ╎         ╎
╎  ╎  └──────────────────────┘             ╎         ╎
╎  ╎  ┌─ login ──────────────┐             ╎         ╎
╎  ╎  │ ● user: string       │             ╎         ╎
╎  ╎  │ ● pass: string       │             ╎         ╎
╎  ╎  └──────────────────────┘             ╎         ╎
╎  └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘         ╎
└╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

---

## 4. Универсальный узел (UniversalNode)

Все 6 типов узлов рисуются **одним шаблоном**. Узел = прямоугольник (Header + опциональные Attributes). Вложенные узлы размещаются не внутри узла, а в **Shadow (Тени)** — отдельной области с пунктирной границей. Различия между типами задаются **конфигурацией**.

### 4.1. Компоненты узла

```
                  ● top
         ┌────────┼───────────────────────────┐
      ●──│ [±] «st» Label        │ ValueType  │──●    ← 1. HEADER
         ├───────────────────────┼────────────┤╌╌╌╌╌╌╌╌╌┐
      ●──│ attrLabel             │ attrValue  │──●      ╎ ← 2. ATTRIBUTES
      ●──│ attrLabel             │ attrValue  │──●      ╎
         └───────────────────────┴────────────┘         ╎
         ╎          ● bottom                            ╎ ← 3. SHADOW
         ╎                                              ╎
         ╎    (вложенные узлы)                          ╎
         ╎                                              ╎
         └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

#### Компонент 1: Header (обязательный)

Заголовок — единственный **обязательный** компонент. Всегда одна строка.

| Часть | Описание | Видимость |
|---|---|---|
| Collapse icon | `[+]` / `[−]` | Если есть children |
| Stereotype | `«class»`, `«module»` и т.д. перед именем | По конфигу type |
| Label | Имя узла | Всегда |
| ValueType | Тип возврата / тип данных (правая часть) | Если `headerSplit = true` |
| Icon | `[×]`, `[→]` и т.д. | Только ref |
| Note badges | `📌` (todo), `⚠` (fixme) | Если есть `notes[]` |

**Header может быть:**
- **Single**: `[±] «stereotype» Label` — для group, block, ref, meta
- **Split**: `[±] «stereotype» Label │ ValueType` — для func (returnType), value (valueType)

#### Компонент 2: Attributes (опциональный)

Строки `label │ valueType` под заголовком. Каждая строка может иметь коннекторы left/right.

| Применение | Что содержат |
|---|---|
| block | extends/implements строки |
| func | аргументы (имя │ тип) |
| meta | параметры (key │ value) |
| ref | subtitle (путь модуля) — как одна строка без split |

#### Компонент 3: Shadow — Тень (опциональный)

Отдельная область с **пунктирной границей**, в которой размещаются вложенные узлы (children). Shadow — **не часть прямоугольника узла**, а связанная с ним область.

**Позиционирование Shadow:**

| Граница | Привязка |
|---|---|
| **Верх** | Нижняя граница Header |
| **Лево** | Левая граница узла |
| **Право / Низ** | Расширяются при перемещении вложенных узлов |

Вложенные узлы можно двигать внутри Shadow, расширяя её **только вправо и вниз**. Внутри Shadow действует padding.

**Стиль Shadow:**

| Свойство | Значение |
|---|---|
| Граница | **dashed** 1px |
| Цвет границы | Совпадает с `borderColor` узла |
| Фон | `fillColor` заголовка с **opacity 0.05** |
| Скругление | Совпадает со скруглением узла |

**Поведение при свёртке / раскрытии:**

| Состояние | Shadow | Вложенные узлы | Связи вложенных |
|---|---|---|---|
| **Развёрнут** `[−]` | Видна | Видны | Приходят на вложенные узлы |
| **Свёрнут** `[+]` | Скрыта | Скрыты | **Перенаправляются** на родительский узел |

При переключении `[+]` ↔ `[−]` связи плавно переходят между родителем и вложенными узлами.

**Содержимое Shadow по type:**

| type | Что содержит Shadow |
|---|---|
| group | Вложенные файлы, классы |
| block | Конструкторы, поля, методы |
| func | Тело — вызовы, присваивания |
| value | Вложенная структура (сложный объект) |

**Порядок children внутри block** (по категориям, по наличию):

| # | Категория | type / stereotype | Показывается если |
|---|---|---|---|
| 1 | Конструктор | `func / constructor` | Есть конструктор |
| 2 | Поля | `value / field` | Есть поля класса |
| 3 | Геттеры/Сеттеры | `func / getter`, `func / setter` | Есть |
| 4 | Методы | `func / method` | Есть методы |

Пустые категории **не отображаются** и не занимают место.

#### Компонент 4: Connectors

4 точки на узле + 2 на каждом атрибуте (left, right):
- **top** — по центру ширины Header
- **left / right** — по центру высоты Header
- **bottom** — по центру ширины Shadow (если Shadow видна; иначе — по центру ширины узла)

Стиль — по `connectionType` узла (см. раздел 2).

#### Компонент 5: Collapse icon

Иконка `[+]`/`[−]` в заголовке. Показывается только если у узла есть или могут быть children. Управляет видимостью Shadow и вложенных узлов.

#### Компонент 6: Modifiers

Полоски доступа (private, protected), бейджи (async, override), эффекты текста (static, abstract). Подробно — в разделе 5.

### 4.2. Конфигурация компонентов по type

| Компонент | group | block | func | value | ref | meta |
|---|---|---|---|---|---|---|
| **Header split** | — | — | ✓ (returnType) | ✓ (valueType) | — | — |
| **Header stereotype** | ✓ | ✓ | opt | — | — | — |
| **Header icon** | — | — | — | — | ✓ `[×]`/`[→]` | — |
| **Attributes** | — | ✓ extends/impl | ✓ аргументы | — | opt (subtitle) | opt (параметры) |
| **Shadow** | ✓ | ✓ | ✓ | opt | — | — |
| **Collapse** | ✓ | ✓ | ✓ | opt | — | — |
| **Connectors** | ✓ 4 | ✓ 4+attr | ✓ 4+attr | ✓ 4 | ✓ 4 | ✓ 4 |
| **Modifiers** | — | ✓ | ✓ | ✓ | — | — |

### 4.3. Визуальные примеры по type

#### group (свёрнут / развёрнут)

```
  Свёрнут:                         Развёрнут:
  ┌──────────────────────────┐     ┌──────────────────────────┐
  │ [+] «module» auth        │     │ [−] «module» auth        │
  └──────────────────────────┘     └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
                                   ╎                                 ╎
                                   ╎    (children)                   ╎
                                   ╎                                 ╎
                                   └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

#### block (свёрнут / развёрнут)

```
  Свёрнут:                              Развёрнут:
           ┌──────────────────────┐                ┌──────────────────────┐
        ●──│ «class» Auth    [+]  │──●          ●──│ «class» Auth    [−]  │──●
           ├────────────┬─────────┤                ├────────────┬─────────┤╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
        ●──│ extends    │ Base    │──●          ●──│ extends    │ Base    │──●           ╎
           └────────────┴─────────┘                └────────────┴─────────┘              ╎
                                                   ╎                                     ╎
                                                   ╎  ┌─ «ctor» constructor ─────┐       ╎
                                                   ╎  │  http   │ HttpClient     │       ╎
                                                   ╎  └─────────┴────────────────┘       ╎
                                                   ╎  ┌─ «method» login ─── →P ──┐       ╎
                                                   ╎  │  user   │ string         │       ╎
                                                   ╎  └─────────┴────────────────┘       ╎
                                                   └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

#### func (свёрнут / развёрнут)

```
  Свёрнут:                                    Развёрнут:
         ┌────────────────┬───────────────┐              ┌────────────────┬───────────────┐
      ●──│  getProjects   │ → Promise<T>  │──●        ●──│  getProjects   │ → Promise<T>  │──●
         ├────────────────┼───────────────┤              ├────────────────┼───────────────┤╌╌╌╌╌╌┐
      ●──│ filter         │ string    [+] │──●        ●──│ filter         │ string    [−] │──●   ╎
         └────────────────┴───────────────┘              └────────────────┴───────────────┘      ╎
                                                         ╎                                       ╎
                                                         ╎  (children: тело)                     ╎
                                                         ╎                                       ╎
                                                         └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
```

#### value

```
   ●──┌──────────────┬──────────┐──●
      │  apiUrl      │ String   │
      └──────────────┴──────────┘
```

#### ref

```
   ┌──[×]─────────────────────┐──●
   │  HttpClient              │
   │  @angular/common/http    │
   └──────────────────────────┘
```

#### meta

```
   ┌──────────────────────────┐──●       ┌──────────────────────────┐──●
   │  @Injectable             │          │  @Component              │
   └──────────────────────────┘          ├──────────────────────────┤
                                         │  selector: 'app-root'    │
                                         └──────────────────────────┘
```

### 4.4. Палитра по stereotype

#### block

| stereotype  | fillColor заголовка        | borderColor | Описание                       |
|-------------|----------------------------|-------------|--------------------------------|
| `class`     | `#B3D9FF` голубой          | `#4A90D9`   | Стандартный класс              |
| `abstract`  | `#D4B3FF` лавандовый       | `#8B6DB5`   | Абстрактный (курсив заголовок) |
| `interface` | `#E0D4FF` фиолетовый       | `#9B8EC4`   | Интерфейс                      |
| `enum`      | `#FFE0B3` персиковый       | `#D4A054`   | Перечисление                   |
| `struct`    | `#D4EDDA` зелёноватый      | `#7CB987`   | Структура                      |
| `type`      | `#E8E0F0` светло-лиловый   | `#A094B5`   | Тип-алиас                      |
| `mixin`     | `#E0F0F0` бледно-бирюзовый | `#7BB5B5`   | Примесь                        |

#### func

| stereotype    | fillColor заголовка      | Описание           |
|---------------|--------------------------|--------------------|
| `function`    | `#E8E8E8` серый          | Standalone-функция |
| `method`      | `#FFFFB3` жёлтый         | Метод класса       |
| `constructor` | `#B3E6D4` бирюзовый      | Конструктор        |
| `getter`      | `#F0D4D4` светло-красный | Геттер             |
| `setter`      | `#D4F0D4` светло-зеленый | Сеттер             |
| `lambda`      | `#F0E8E8` розоватый      | Лямбда             |

#### value

| stereotype | fillColor | borderStyle | Описание |
|---|---|---|---|
| `variable` | `#FFF3B3` тёпло-жёлтый | solid 1px | Изменяемая |
| `constant` | `#B3FFB3` зелёный | solid 2px | Неизменяемая |
| `field` | `#E8F4FF` бледно-голубой | solid 1px | Поле класса |
| `property` | `#E8F4FF` бледно-голубой | solid 1px | Свойство |
| `param` | `#F0F0F0` серый | dashed 1px | Параметр |

#### group, ref, meta

| type | fillColor | borderColor | borderStyle | Описание |
|---|---|---|---|---|
| `group` | `#FAFAFA` (opacity 0.3) | `#BDBDBD` | dashed 1px | Контейнер |
| `ref` | `#F0F0F0` | `#AAAAAA` | dashed 1px | Ссылка |
| `meta` | `#FFD4B3` | `#E8A050` | solid 1px | Метаданные |
| `meta/legend` | `#FFFFFF` | `#CCCCCC` | solid 1px | Легенда |

### 4.5. Общие стили

- **Скруглённые углы**: 8px (group, block, func), 6px (value), 4px (ref, meta)
- **Заголовок**: жирный 12px (block, func), обычный 12px (group, value, ref, meta)
- **Стереотип**: 10px, `#666`, перед именем
- **Атрибуты**: 2 колонки (label │ valueType), разделитель `#E0E0E0` 1px, высота строки 22px
- **Shadow padding**: 8px внутри, gap 8px между children, 12px между категориями
- **Shadow border**: dashed 1px, цвет = borderColor узла
- **Shadow background**: fillColor заголовка, opacity 0.05

---

## 5. Модификаторы узлов

Модификаторы хранятся в поле `modifiers: string[]` и отображаются как **визуальные индикаторы** на узле.

### 5.1. Модификаторы доступа

| Модификатор | Визуал | Где | Языки |
|---|---|---|---|
| `public` | Нет маркера (по умолчанию) | — | Все |
| `private` | Вертикальная красная полоска (3px) у левого края | Заголовок | Все |
| `protected` | Вертикальная жёлтая полоска (3px) у левого края | Заголовок | Java, Kotlin, C#, C++, Dart |
| `internal` | Вертикальная серая полоска (3px) у левого края | Заголовок | C#, Kotlin |
| `fileprivate` | Вертикальная тёмно-красная полоска (3px) | Заголовок | Swift |
| `open` | Вертикальная зелёная полоска (3px) | Заголовок | Kotlin, Swift |
| `package` | Вертикальная голубая полоска (3px) | Заголовок | Java (module) |

```
  public:            private:            protected:
┌─────────────┐   ┃┌─────────────┐   ┃┌─────────────┐
│ AuthService │   ┃│ _http       │   ┃│ onCreate()  │
└─────────────┘   ┃└─────────────┘   ┃└─────────────┘
                  красная              жёлтая
```

### 5.2. Модификаторы поведения

| Модификатор | Визуал | Где | Языки |
|---|---|---|---|
| `async` | Бейдж `⚡` в правом верхнем углу заголовка | Заголовок func | JS/TS, Dart, Python, C#, Rust |
| `static` | Подчёркнутый текст заголовка (UML-конвенция) | Заголовок | Все |
| `abstract` | Курсив текст заголовка | Заголовок | Java, Dart, Kotlin, C#, C++ |
| `override` | Бейдж `↑` в правом верхнем углу | Заголовок func | Java, Dart, Kotlin, C#, C++ |
| `readonly` | Бейдж `R` слева от имени, серый | Атрибут value | TS, C# |
| `final` | Двойная рамка (рамка + 2px отступ + рамка) | Весь узел | Java, Dart, Kotlin |
| `sealed` | Двойная рамка | Весь узел | Kotlin, Java, C#, Dart |
| `deprecated` | Зачёркнутый текст + `opacity: 0.5` | Весь узел | Все |
| `optional` | `?` после имени, `opacity: 0.7` | Атрибут | TS, Dart, Swift, Kotlin |
| `suspend` | Бейдж `⏸` в правом верхнем углу | Заголовок func | Kotlin |
| `inline` | Бейдж `▸` в правом верхнем углу | Заголовок func | Kotlin, C/C++, Rust |
| `virtual` | Курсив текст (как abstract, но обычный цвет) | Заголовок | C++, C# |
| `native` / `extern` | Бейдж `N` слева, серый | Заголовок func | Java (JNI), Dart (FFI), C# (P/Invoke), Rust |
| `lazy` / `late` | Бейдж `L` слева, серый | Атрибут value | Swift, Dart, Kotlin, Rust |
| `volatile` | Бейдж `V` слева, серый | Атрибут value | Java, C/C++, C# |
| `transient` | Бейдж `T` слева, серый | Атрибут value | Java |
| `const` | Бейдж `C` слева, зелёный | Атрибут value | Все (compile-time constant) |

```
  async method:           static field:           deprecated:
┌──────────────── ⚡┐  ┌──────────────────┐    ┌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┐
│  fetchData       │    │  ̲i̲n̲s̲t̲a̲n̲c̲e̲        │    │ ̶o̶l̶d̶M̶e̶t̶h̶o̶d̶(̶)̶   │
├──────────────────┤    └──────────────────┘    └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘
│ ● url: string    │                               opacity: 0.5
└──────────────────┘

  readonly:               final class:
┌──────────────────┐    ┌══════════════════┐
│  R name: string  │    ║  UserService     ║
└──────────────────┘    └══════════════════┘
```

### 5.3. Комбинации

Модификаторы комбинируются. Пример: `private + async + override`:
```
┃┌──────────────── ⚡↑┐
┃│  _fetchData         │
┃├─────────────────────┤
┃│ ● url: string       │
┃└─────────────────────┘
 красная полоска
```

---

## 6. Связь (Arrow)

### 6.1. Типы связей (5 типов)

| type | Назначение | Линия | Толщина | Цвет |
|---|---|---|---|---|
| `inherit` | Структурная иерархия (extends, implements, mixin) | solid / dashed / dotted | 1.5px | `#333333` чёрный |
| `depend` | Зависимость (import, inject, type usage) | dashed | 1px | `#888888` серый |
| `flow` | Поток данных/управления (call, return, emit, assign) | solid | 1.5px | `#4488CC` синий |
| `own` | Владение (compose, aggregate) | solid | 1.5px | `#333333` чёрный |
| `meta` | Метаданные (annotate, document) | dotted | 1px | `#FF8800` оранжевый |

### 6.2. Оформление концов связей

| type | Source (начало) | Target (конец) | Варианты |
|---|---|---|---|
| `inherit` | — (нет маркера) | △ пустой треугольник (12×8px) | solid=extends, dashed=implements, dotted=mixin |
| `depend` | — | ▶ заполненный треугольник (8×6px) | — |
| `flow` | ○ пустой круг (6px) | ▶ заполненный треугольник (8×6px) | return: направление инвертировано, зелёный `#4CAF50` |
| `own` | ◆ заполненный ромб (10×6px) | — | compose=◆ заполненный, aggregate=◇ пустой |
| `meta` | — | ○ пустой круг (6px) | — |

### 6.3. Оформление линий

Все линии **ортогональные** с 0–4 коленами и **скруглениями в поворотах** (radius 6px).

| Стиль линии | Вид | Использование |
|---|---|---|
| solid | ──────── | inherit(extends), flow, own |
| dashed | ╌╌╌╌╌╌╌╌ (8px dash, 4px gap) | inherit(implements), depend |
| dotted | ·················· (2px dot, 4px gap) | inherit(mixin), meta |

### 6.4. Оформление середины связи (опционально)

- **Подпись (power)**: текст на средней точке линии, белый фон-подложка, 10px, `#555`
- **Мощность**: рядом с концом в кружке (`1`, `N`) — 9px, `#888`
- **Направление потока**: на длинных сегментах ≥80px — мелкий шеврон `›` по центру сегмента, цвет линии, `opacity: 0.5`

```
  inherit (extends):          depend (import):
  ───────────────△            ╌╌╌╌╌╌╌╌╌╌╌╌▶

  inherit (implements):       flow (call):
  ╌╌╌╌╌╌╌╌╌╌╌╌╌△             ○──── › ────▶

  inherit (mixin):            flow (return):
  ·················△          ◁╌╌╌╌ › ╌╌╌╌○   (зелёный, инверсия)

  own (compose):              own (aggregate):
  ◆─────────────              ◇─────────────

  meta (annotate):
  ···················○
```

### 6.5. Подтип связи

Подтип определяется полем `stereotype` стрелки, аналогично узлам:

| type связи | stereotype | Визуал | Языки |
|---|---|---|---|
| `inherit` | `"extends"` | solid + △ | Все |
| | `"implements"` | dashed + △ | Java, Dart, TS, C# |
| | `"mixin"` | dotted + △ | Dart, Ruby |
| | `"with"` | dotted + △ | Dart (`with Mixin`) |
| | `"conforms"` | dashed + △ | Swift (protocol conformance) |
| | `"trait_impl"` | dashed + △ | Rust (`impl Trait for Struct`) |
| `depend` | `"import"` | dashed ▶ | Все |
| | `"inject"` | dashed ▶ | Java/Dart (DI), TS (Angular) |
| | `"type_ref"` | dashed ▶ | Все (ссылка на тип) |
| | `"generic"` | dashed ▶ | Все (параметр типа `<T>`) |
| `flow` | `"call"` | solid синий ○──▶ | Все |
| | `"return"` | dashed зелёный ◁╌╌○ | Все |
| | `"emit"` | solid фиолетовый `#9C27B0` ○──▶ | JS/Dart (EventEmitter, Stream) |
| | `"yield"` | dotted синий ○··▶ | JS/TS, Python, Dart (`sync*`) |
| | `"await"` | dashed синий ○╌╌▶ | Все (async/await) |
| | `"send"` | solid синий ○──▶ | Go (channel send `ch <-`) |
| | `"receive"` | dashed зелёный ◁╌╌○ | Go (channel receive `<-ch`) |
| | `"subscribe"` | solid фиолетовый ○──▶ | RxJS, Dart Streams |
| `own` | `"compose"` | ◆── | Все (сильная вложенность) |
| | `"aggregate"` | ◇── | Все (слабая ссылка) |
| `meta` | `"annotate"` | dotted ○ | Все (decorator→target) |
| | `"document"` | dotted ○ | Все (doc→element) |

---

## 7. Заметки (Notes)

Заметки хранятся **внутри узла**, к которому относятся, в поле `notes[]`. Отдельного типа узла для заметок нет.

### 7.1. Структура notes[]

```json
"notes": [
  { "type": "doc",   "text": "Авторизация пользователя по логину/паролю" },
  { "type": "todo",  "text": "add input validation" },
  { "type": "fixme", "text": "handle network timeout" }
]
```

### 7.2. Типы заметок и отображение

| type | Источник в коде | Отображение | Визуал |
|---|---|---|---|
| `doc` | JSDoc, Javadoc, docstring, `///` | Tooltip при наведении на узел | Всплывающая подсказка |
| `todo` | `// TODO:` | Бейдж `📌` в правом верхнем углу заголовка + tooltip | Жёлтый бейдж |
| `fixme` | `// FIXME:` | Бейдж `⚠` в правом верхнем углу заголовка + tooltip | Оранжевый бейдж |
| `comment` | Обычный комментарий | Не отображается (data-only) | — |

### 7.3. Tooltip

| Уровень | Поле | Отображение |
|---|---|---|
| Узел | `notes[type=doc].text` или `tooltip` | Tooltip при наведении на заголовок |
| Атрибут | `user_object.tooltip` | Tooltip при наведении на строку-атрибут |

Если у узла есть несколько заметок, tooltip объединяет их с разделителем.

### 7.4. Бейджи заметок

Бейджи `📌` и `⚠` показываются в **правом верхнем углу заголовка** рядом с бейджами модификаторов (async, override). При наведении на бейдж — tooltip с текстом заметки.

Если у узла несколько todo/fixme — показывается один бейдж с числом: `📌3`, `⚠2`.

---

## 8. Легенда

Отдельный узел `type: meta, stereotype: "legend"` в углу диаграммы. Не подключается к другим узлам.

```
┌─── Легенда ───────────────────────────────────────────────┐
│                                                           │
│  Узлы:                                                    │
│  [голубой]     block/class     [лавандовый] block/abstract│
│  [фиолетовый] block/interface  [персиковый] block/enum    │
│  [серый]       func/function   [жёлтый]     func/method   │
│  [бирюзовый]  func/constructor [зелёный]    value/const   │
│  [оранжевый]  meta/decorator   [серый]      ref/import    │
│                                                           │
│  Коннекты (по 1 точке на сторону, один тип на узел):      │
│  ● зелёная = in      ● красная = out                      │
│  ○ белая с обводкой = inout                               │
│  left/right — по центру заголовка                         │
│  top/bottom — по центру ширины узла                       │
│                                                           │
│  Связи (ортогональные, скругления 6px):                   │
│  ────△  inherit/extends    ╌╌╌△  inherit/implements      │
│  ◆────  own/compose        ◇────  own/aggregate          │
│  ╌╌╌▶  depend              ○──▶  flow/call               │
│  ◁╌╌○  flow/return (зел.) ·····○  meta/annotate          │
│                                                           │
│  Модификаторы:                                            │
│  ┃ красная = private   ┃ жёлтая = protected               │
│  ⚡ async   ↑ override   R readonly                      │
│  подчёркнутый = static   курсив = abstract                │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

---

## 9. JSON-структура

### 9.1. Узел (block)

```json
{
  "id": "class_auth",
  "label": "AuthService",
  "type": "block",
  "stereotype": "class",
  "modifiers": ["public"],
  "connectionType": "inout",
  "notes": [
    { "type": "doc", "text": "Сервис аутентификации пользователей" }
  ],
  "attributes": [
    {
      "id": "a_extends_base",
      "label": "extends",
      "valueType": "BaseService",
      "connectionType": "inout"
    },
    {
      "id": "a_impl_auth",
      "label": "implements",
      "valueType": "IAuthable",
      "connectionType": "inout"
    }
  ],
  "children": [
    {
      "id": "ctor_auth",
      "label": "constructor",
      "type": "func",
      "stereotype": "constructor",
      "modifiers": ["public"],
      "connectionType": "inout",
      "attributes": [
        {
          "id": "arg_http",
          "label": "http",
          "valueType": "HttpClient",
          "modifiers": ["private"],
          "connectionType": "in"
        },
        {
          "id": "arg_gateway",
          "label": "gateway",
          "valueType": "ApiUrl",
          "modifiers": ["private", "readonly"],
          "connectionType": "in"
        }
      ],
      "geometry": { "x": 20, "y": 80, "width": 400, "height": 100 }
    },
    {
      "id": "field_http",
      "label": "_http",
      "type": "value",
      "stereotype": "field",
      "valueType": "HttpClient",
      "modifiers": ["private"],
      "connectionType": "in",
      "geometry": { "x": 20, "y": 190, "width": 200, "height": 30 }
    },
    {
      "id": "field_token",
      "label": "_token",
      "type": "value",
      "stereotype": "field",
      "valueType": "string",
      "modifiers": ["private"],
      "connectionType": "inout",
      "geometry": { "x": 20, "y": 230, "width": 200, "height": 30 }
    },
    {
      "id": "method_login",
      "label": "login",
      "type": "func",
      "stereotype": "method",
      "modifiers": ["public", "async"],
      "connectionType": "inout",
      "returnType": "Promise<Token>",
      "attributes": [
        { "id": "arg_user", "label": "user", "valueType": "string", "connectionType": "in" },
        { "id": "arg_pass", "label": "pass", "valueType": "string", "connectionType": "in" }
      ],
      "children": [],
      "geometry": { "x": 20, "y": 270, "width": 400, "height": 120 }
    }
  ],
  "geometry": { "x": 200, "y": 40, "width": 460, "height": 420 }
}
```

### 9.2. Связь (arrow)

```json
{
  "id": "arr_extends_base",
  "type": "inherit",
  "stereotype": "extends",
  "source": "class_auth",
  "target": "ref_baseservice",
  "targetArrow": "diamond_empty"
}
```

```json
{
  "id": "arr_inject_http",
  "type": "depend",
  "stereotype": "inject",
  "source": "ref_httpclient",
  "target": "arg_http",
  "targetArrow": "block",
  "powers": [
    { "id": "p1", "value": "inject", "side": "1" }
  ]
}
```

```json
{
  "id": "arr_call_http_get",
  "type": "flow",
  "stereotype": "call",
  "source": "call_login_http_get",
  "target": "field_http",
  "style": "strokeColor=#4488CC;strokeWidth=1.5",
  "sourceArrow": "oval",
  "targetArrow": "block",
  "powers": [
    { "id": "p2", "value": "N", "side": "target" }
  ]
}
```

---

## 10. Настройки стилей (Style Config)

Стили всех элементов диаграммы загружаются из **внешнего JSON-файла** настроек. Это позволяет менять визуал без изменения данных диаграммы.

### 10.1. Структура файла

```json
{
  "version": "1.0",
  "global": { ... },
  "nodes": { ... },
  "arrows": { ... },
  "connectors": { ... },
  "modifiers": { ... }
}
```

### 10.2. Глобальные настройки (`global`)

```json
"global": {
  "fontFamily": "Inter, system-ui, sans-serif",
  "fontSize": 12,
  "lineHeight": 1.4,
  "backgroundColor": "#FFFFFF",
  "selectionColor": "#2196F3",
  "selectionWidth": 2,
  "gridSize": 10,
  "snapToGrid": true,
  "animationDuration": 200
}
```

### 10.3. Настройки узлов (`nodes`)

Иерархия применения: `nodes.default` → `nodes.byType[type]` → `nodes.byStereotype[type/stereotype]`. Более конкретные настройки переопределяют менее конкретные.

#### 10.3.1. Шаблон узла (все поля)

```json
{
  "content": {
    "showStereotype": true,
    "showAttributes": true,
    "showShadow": true,
    "showConnectors": true,
    "showCollapseButton": true,
    "showTooltip": true,
    "showReturnType": true,
    "showModifiers": true,
    "attributeColumns": 2,
    "childrenCategoryOrder": ["constructor", "field", "getter", "setter", "method"]
  },
  "header": {
    "fillColor": "#B3D9FF",
    "fontColor": "#000000",
    "fontSize": 12,
    "fontWeight": "bold",
    "fontStyle": "normal",
    "textAlign": "left",
    "padding": { "top": 6, "right": 10, "bottom": 6, "left": 10 },
    "stereotypeColor": "#666666",
    "stereotypeFontSize": 10,
    "returnTypeFontSize": 11,
    "returnTypeColor": "#555555"
  },
  "shadow": {
    "fillColor": "auto",
    "fillOpacity": 0.05,
    "borderStyle": "dashed",
    "borderWidth": 1,
    "padding": { "top": 8, "right": 8, "bottom": 8, "left": 8 }
  },
  "attribute": {
    "height": 22,
    "dividerColor": "#E0E0E0",
    "dividerWidth": 1,
    "labelColor": "#333333",
    "valueColor": "#555555",
    "labelFontSize": 11,
    "valueFontSize": 11,
    "hoverBackground": "#F5F5F5"
  },
  "border": {
    "color": "#4A90D9",
    "width": 1.5,
    "style": "solid",
    "radius": 8,
    "opacity": 1.0
  },
  "shadow": {
    "enabled": false,
    "color": "rgba(0,0,0,0.15)",
    "blur": 4,
    "offsetX": 1,
    "offsetY": 2
  },
  "spacing": {
    "childrenGap": 8,
    "categoryGap": 12,
    "childPadding": { "top": 8, "right": 12, "bottom": 8, "left": 12 }
  }
}
```

#### 10.3.2. Настройки по type (`nodes.byType`)

```json
"nodes": {
  "default": { "..." : "шаблон по умолчанию" },

  "byType": {
    "group": {
      "content": {
        "showAttributes": false,
        "showConnectors": true,
        "showCollapseButton": true,
        "showReturnType": false
      },
      "header": {
        "fillColor": "transparent",
        "fontColor": "#666666",
        "fontSize": 12,
        "fontWeight": "normal"
      },
      "shadow": {
        "fillColor": "#FAFAFA",
        "fillOpacity": 0.05
      },
      "border": {
        "color": "#BDBDBD",
        "width": 1,
        "style": "dashed",
        "radius": 8
      }
    },

    "block": {
      "content": {
        "showAttributes": true,
        "showShadow": true,
        "childrenCategoryOrder": ["constructor", "field", "getter", "setter", "method"]
      },
      "header": {
        "fontWeight": "bold",
        "fontSize": 12
      },
      "shadow": {
        "fillColor": "auto"
      },
      "border": {
        "width": 1.5,
        "style": "solid",
        "radius": 8
      }
    },

    "func": {
      "content": {
        "showAttributes": true,
        "showReturnType": true
      },
      "header": {
        "fontWeight": "bold",
        "fontSize": 12
      },
      "border": {
        "color": "#555555",
        "width": 1,
        "style": "solid",
        "radius": 8
      }
    },

    "value": {
      "content": {
        "showAttributes": false,
        "showShadow": false,
        "showCollapseButton": false,
        "showReturnType": false
      },
      "border": {
        "color": "#888888",
        "width": 1,
        "style": "solid",
        "radius": 6
      }
    },

    "ref": {
      "content": {
        "showAttributes": false,
        "showShadow": false,
        "showCollapseButton": false
      },
      "border": {
        "color": "#AAAAAA",
        "width": 1,
        "style": "dashed",
        "radius": 4
      }
    },

    "meta": {
      "content": {
        "showShadow": false,
        "showCollapseButton": false
      },
      "header": {
        "fillColor": "#FFD4B3",
        "fontColor": "#664400"
      },
      "border": {
        "color": "#E8A050",
        "width": 1,
        "style": "solid",
        "radius": 4
      }
    }
  }
}
```

#### 10.3.3. Настройки по stereotype (`nodes.byStereotype`)

Ключ — `"type/stereotype"`. Переопределяет только указанные поля поверх `byType`.

```json
"nodes": {
  "byStereotype": {
    "block/class":     { "header": { "fillColor": "#B3D9FF" }, "border": { "color": "#4A90D9" } },
    "block/abstract":  { "header": { "fillColor": "#D4B3FF", "fontStyle": "italic" }, "border": { "color": "#8B6DB5" } },
    "block/interface": { "header": { "fillColor": "#E0D4FF" }, "border": { "color": "#9B8EC4", "topWidth": 3 } },
    "block/enum":      { "header": { "fillColor": "#FFE0B3" }, "border": { "color": "#D4A054" } },
    "block/struct":    { "header": { "fillColor": "#D4EDDA" }, "border": { "color": "#7CB987" } },
    "block/type":      { "header": { "fillColor": "#E8E0F0" }, "border": { "color": "#A094B5" } },
    "block/mixin":     { "header": { "fillColor": "#E0F0F0" }, "border": { "color": "#7BB5B5", "style": "dash-dot" } },

    "func/function":    { "header": { "fillColor": "#E8E8E8" } },
    "func/method":      { "header": { "fillColor": "#FFFFB3" } },
    "func/constructor": { "header": { "fillColor": "#B3E6D4" }, "border": { "topWidth": 3 } },
    "func/getter":      { "header": { "fillColor": "#D4F0E8" } },
    "func/setter":      { "header": { "fillColor": "#D4F0E8" } },
    "func/lambda":      { "header": { "fillColor": "#F0E8E8" } },

    "value/variable": { "header": { "fillColor": "#FFF3B3" } },
    "value/constant": { "header": { "fillColor": "#B3FFB3" }, "border": { "width": 2 } },
    "value/field":    { "header": { "fillColor": "#E8F4FF" } },
    "value/property": { "header": { "fillColor": "#E8F4FF" } },
    "value/param":    { "header": { "fillColor": "#F0F0F0" }, "border": { "style": "dashed" } },

    "meta/legend":    { "header": { "fillColor": "#FFFFFF" }, "border": { "color": "#CCCCCC" } }
  }
}
```

### 10.4. Настройки связей (`arrows`)

Иерархия: `arrows.default` → `arrows.byType[type]` → `arrows.byStereotype[type/stereotype]`.

#### 10.4.1. Шаблон связи (все поля)

```json
{
  "line": {
    "color": "#888888",
    "width": 1,
    "style": "solid",
    "dashPattern": null,
    "opacity": 1.0,
    "orthogonal": true,
    "turnRadius": 6,
    "maxKnees": 4
  },
  "sourceEnd": {
    "type": "none",
    "size": { "width": 8, "height": 6 },
    "fillColor": null,
    "strokeColor": null,
    "strokeWidth": 1
  },
  "targetEnd": {
    "type": "none",
    "size": { "width": 8, "height": 6 },
    "fillColor": null,
    "strokeColor": null,
    "strokeWidth": 1
  },
  "power": {
    "fontSize": 9,
    "fontColor": "#888888",
    "backgroundColor": "#FFFFFF",
    "borderColor": "#CCCCCC",
    "borderRadius": 8,
    "padding": 3,
    "offset": 6
  },
  "label": {
    "fontSize": 10,
    "fontColor": "#555555",
    "backgroundColor": "#FFFFFF",
    "backgroundOpacity": 0.9,
    "padding": 4,
    "position": "middle"
  },
  "chevron": {
    "enabled": true,
    "minSegmentLength": 80,
    "symbol": "›",
    "opacity": 0.5,
    "fontSize": 12
  }
}
```

**Допустимые значения `sourceEnd.type` / `targetEnd.type`:**

| type | Вид | Описание |
|---|---|---|
| `"none"` | — | Нет маркера |
| `"triangle_empty"` | △ | Пустой треугольник (inherit) |
| `"triangle_filled"` | ▶ | Заполненный треугольник (depend, flow) |
| `"diamond_filled"` | ◆ | Заполненный ромб (compose) |
| `"diamond_empty"` | ◇ | Пустой ромб (aggregate) |
| `"circle_empty"` | ○ | Пустой круг (flow source, meta target) |
| `"circle_filled"` | ● | Заполненный круг |

#### 10.4.2. Настройки по type (`arrows.byType`)

```json
"arrows": {
  "default": { "...": "шаблон по умолчанию" },

  "byType": {
    "inherit": {
      "line": { "color": "#333333", "width": 1.5, "style": "solid" },
      "sourceEnd": { "type": "none" },
      "targetEnd": { "type": "triangle_empty", "size": { "width": 12, "height": 8 } }
    },
    "depend": {
      "line": { "color": "#888888", "width": 1, "style": "dashed", "dashPattern": [8, 4] },
      "sourceEnd": { "type": "none" },
      "targetEnd": { "type": "triangle_filled", "size": { "width": 8, "height": 6 } }
    },
    "flow": {
      "line": { "color": "#4488CC", "width": 1.5, "style": "solid" },
      "sourceEnd": { "type": "circle_empty", "size": { "width": 6, "height": 6 } },
      "targetEnd": { "type": "triangle_filled", "size": { "width": 8, "height": 6 } }
    },
    "own": {
      "line": { "color": "#333333", "width": 1.5, "style": "solid" },
      "sourceEnd": { "type": "diamond_filled", "size": { "width": 10, "height": 6 } },
      "targetEnd": { "type": "none" }
    },
    "meta": {
      "line": { "color": "#FF8800", "width": 1, "style": "dotted", "dashPattern": [2, 4] },
      "sourceEnd": { "type": "none" },
      "targetEnd": { "type": "circle_empty", "size": { "width": 6, "height": 6 } }
    }
  }
}
```

#### 10.4.3. Настройки по stereotype (`arrows.byStereotype`)

```json
"arrows": {
  "byStereotype": {
    "inherit/extends":    { "line": { "style": "solid" } },
    "inherit/implements": { "line": { "style": "dashed", "dashPattern": [8, 4] } },
    "inherit/mixin":      { "line": { "style": "dotted", "dashPattern": [2, 4] } },
    "inherit/with":       { "line": { "style": "dotted" } },

    "flow/call":          { "line": { "color": "#4488CC" } },
    "flow/return":        { "line": { "color": "#4CAF50", "style": "dashed" }, "sourceEnd": { "type": "triangle_filled" }, "targetEnd": { "type": "circle_empty" } },
    "flow/emit":          { "line": { "color": "#9C27B0" } },
    "flow/yield":         { "line": { "color": "#4488CC", "style": "dotted" } },
    "flow/await":         { "line": { "color": "#4488CC", "style": "dashed" } },

    "own/compose":        { "sourceEnd": { "type": "diamond_filled" } },
    "own/aggregate":      { "sourceEnd": { "type": "diamond_empty" } }
  }
}
```

### 10.5. Настройки коннекторов (`connectors`)

```json
"connectors": {
  "size": 6,
  "hoverSize": 10,
  "byConnectionType": {
    "in": {
      "fillColor": "#4CAF50",
      "strokeColor": null,
      "strokeWidth": 0,
      "shape": "circle_filled"
    },
    "out": {
      "fillColor": "#F44336",
      "strokeColor": null,
      "strokeWidth": 0,
      "shape": "circle_filled"
    },
    "inout": {
      "fillColor": "#FFFFFF",
      "strokeColor": "#888888",
      "strokeWidth": 1,
      "shape": "circle_stroke"
    },
    "none": {
      "visible": false
    }
  }
}
```

### 10.6. Настройки модификаторов (`modifiers`)

#### 10.6.1. Модификаторы доступа (полоски)

```json
"modifiers": {
  "access": {
    "stripeWidth": 3,
    "stripePosition": "left",
    "byModifier": {
      "public":      { "visible": false },
      "private":     { "color": "#F44336" },
      "protected":   { "color": "#FFC107" },
      "internal":    { "color": "#9E9E9E" },
      "fileprivate": { "color": "#B71C1C" },
      "open":        { "color": "#4CAF50" },
      "package":     { "color": "#64B5F6" }
    }
  }
}
```

#### 10.6.2. Модификаторы поведения (бейджи и эффекты)

```json
"modifiers": {
  "behavior": {
    "async":      { "badge": "⚡", "position": "header-top-right", "color": "#FF9800" },
    "override":   { "badge": "↑",  "position": "header-top-right", "color": "#666666" },
    "readonly":   { "badge": "R",  "position": "label-left",       "color": "#9E9E9E" },
    "const":      { "badge": "C",  "position": "label-left",       "color": "#4CAF50" },
    "lazy":       { "badge": "L",  "position": "label-left",       "color": "#9E9E9E" },
    "late":       { "badge": "L",  "position": "label-left",       "color": "#9E9E9E" },
    "volatile":   { "badge": "V",  "position": "label-left",       "color": "#9E9E9E" },
    "transient":  { "badge": "T",  "position": "label-left",       "color": "#9E9E9E" },
    "native":     { "badge": "N",  "position": "label-left",       "color": "#9E9E9E" },
    "suspend":    { "badge": "⏸", "position": "header-top-right", "color": "#666666" },
    "inline":     { "badge": "▸",  "position": "header-top-right", "color": "#666666" },
    "static":     { "effect": "underline" },
    "abstract":   { "effect": "italic" },
    "virtual":    { "effect": "italic" },
    "final":      { "effect": "double-border", "borderGap": 2 },
    "sealed":     { "effect": "double-border", "borderGap": 2 },
    "deprecated": { "effect": "strikethrough", "opacity": 0.5 },
    "optional":   { "effect": "append-?", "opacity": 0.7 }
  },
  "badgeDefaults": {
    "fontSize": 10,
    "fontWeight": "bold",
    "backgroundColor": "transparent",
    "padding": 2,
    "borderRadius": 3
  }
}
```

**Допустимые значения `position`:**

| position | Описание |
|---|---|
| `"header-top-right"` | Правый верхний угол заголовка |
| `"header-top-left"` | Левый верхний угол заголовка |
| `"label-left"` | Слева от текста (имени) элемента |
| `"label-right"` | Справа от текста элемента |

**Допустимые значения `effect`:**

| effect | Описание |
|---|---|
| `"underline"` | Подчёркнутый текст заголовка |
| `"italic"` | Курсив заголовка |
| `"strikethrough"` | Зачёркнутый текст |
| `"double-border"` | Двойная рамка (рамка + gap + рамка) |
| `"append-?"` | Добавляет `?` после имени |

### 10.7. Пример полного файла настроек (минимальный)

```json
{
  "version": "1.0",
  "global": {
    "fontFamily": "Inter, system-ui, sans-serif",
    "fontSize": 12,
    "backgroundColor": "#FFFFFF"
  },
  "nodes": {
    "default": {
      "header": { "fontWeight": "bold", "fontSize": 12 },
      "shadow": { "fillColor": "auto", "fillOpacity": 0.05, "borderStyle": "dashed" },
      "border": { "width": 1, "style": "solid", "radius": 8 }
    },
    "byType": {
      "group": {
        "border": { "style": "dashed", "color": "#BDBDBD" },
        "shadow": { "fillColor": "#FAFAFA", "fillOpacity": 0.05 }
      }
    },
    "byStereotype": {
      "block/class": { "header": { "fillColor": "#B3D9FF" }, "border": { "color": "#4A90D9" } }
    }
  },
  "arrows": {
    "default": {
      "line": { "width": 1, "turnRadius": 6 }
    },
    "byType": {
      "flow": { "line": { "color": "#4488CC", "width": 1.5 } }
    }
  },
  "connectors": {
    "size": 6,
    "hoverSize": 10,
    "byConnectionType": {
      "in":    { "fillColor": "#4CAF50" },
      "out":   { "fillColor": "#F44336" },
      "inout": { "fillColor": "#FFFFFF", "strokeColor": "#888888" }
    }
  },
  "modifiers": {
    "access": {
      "stripeWidth": 3,
      "byModifier": {
        "private":   { "color": "#F44336" },
        "protected": { "color": "#FFC107" }
      }
    },
    "behavior": {
      "async": { "badge": "⚡", "position": "header-top-right" },
      "static": { "effect": "underline" }
    }
  }
}
```

### 10.8. Правила применения

1. **Каскад**: `default` → `byType` → `byStereotype`. Каждый уровень переопределяет только указанные поля (deep merge).
2. **Частичность**: файл настроек может содержать только те секции и поля, которые нужно переопределить. Остальное берётся из встроенных значений по умолчанию.
3. **Валидация**: цвета — hex (`#RRGGBB`, `#RRGGBBAA`) или `rgba()`; размеры — числа в px; `style` линий — `"solid"` | `"dashed"` | `"dotted"` | `"dash-dot"`.
4. **Shadow auto**: `fillColor: "auto"` означает — берётся `header.fillColor` текущего узла с `fillOpacity`.
5. **Загрузка**: файл подключается при инициализации диаграммы. Смена файла перерисовывает все элементы с новыми стилями без потери данных.