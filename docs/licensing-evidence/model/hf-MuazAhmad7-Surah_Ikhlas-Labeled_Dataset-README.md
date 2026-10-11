---
license: cc-by-4.0
task_categories:
  - audio-classification
language:
  - ar
tags:
  - quran
  - tajweed
  - recitation
  - error-detection
  - arabic
  - audio
  - speech
  - islam
pretty_name: Surah Al-Ikhlas Quran Recitation Error Detection Dataset
size_categories:
  - 1K<n<10K
---

# Surah Al-Ikhlas Quran Recitation Error Detection Dataset

## Dataset Description

This dataset contains audio recordings of Quran recitations of **Surah Al-Ikhlas** (Chapter 112 - The Sincerity) with labels indicating whether each recitation contains errors in Tajweed (Quran recitation rules).

### Dataset Summary

| Statistic | Value |
|-----------|-------|
| **Total Samples** | 1,506 |
| **Error Recitations** | 851 (56.5%) |
| **Correct Recitations** | 655 (43.5%) |
| **Verses** | 4 |
| **Audio Format** | WAV |
| **Language** | Arabic |

### Surah Al-Ikhlas Text

| Verse | Arabic | Transliteration | Translation |
|-------|--------|-----------------|-------------|
| 1 | قُلْ هُوَ اللَّهُ أَحَدٌ | Qul huwa Allahu ahad | Say, "He is Allah, [who is] One" |
| 2 | اللَّهُ الصَّمَدُ | Allahu assamad | "Allah, the Eternal Refuge" |
| 3 | لَمْ يَلِدْ وَلَمْ يُولَدْ | Lam yalid walam yulad | "He neither begets nor is born" |
| 4 | وَلَمْ يَكُن لَّهُ كُفُوًا أَحَدٌ | Walam yakun lahu kufuwan ahad | "Nor is there to Him any equivalent" |

## Dataset Structure

### Files

- `data/` - Folder containing all WAV audio files
- `metadata.csv` - CSV file with labels and metadata for each audio file

### Metadata Fields

| Field | Type | Description |
|-------|------|-------------|
| `file_name` | string | Path to audio file (e.g., `data/ID1V1F.wav`) |
| `label` | int | Binary label: 0 = error, 1 = correct |
| `label_name` | string | Label as text: "error" or "correct" |
| `verse_number` | int | Verse number (1-4) |
| `verse_text` | string | Arabic text of the verse |
| `error_type` | string | Type of Tajweed error (Arabic, if applicable) |
| `error_location` | string | Location of error in the verse |
| `error_explanation` | string | Explanation of the error (Arabic) |
| `error_count` | int | Error category number |

### File Naming Convention

Audio files follow the pattern: `ID{participant}V{verse}{T/F}.wav`
- `ID` prefix followed by participant number
- `V` followed by verse number (1-4)
- `T` = True (correct recitation) / `F` = False (contains error)

## Usage

```python
from datasets import load_dataset

# Load the dataset
dataset = load_dataset("MuazAhmad7/Surah_Ikhlas-Labeled_Dataset")

# Access the data
for sample in dataset['train']:
    print(f"File: {sample['file_name']}")
    print(f"Label: {sample['label_name']}")
    print(f"Verse: {sample['verse_number']}")
    break
```

### Loading Audio

```python
import pandas as pd
from datasets import Dataset, Audio

# Load metadata
df = pd.read_csv("metadata.csv")

# Create dataset with audio
dataset = Dataset.from_pandas(df)
dataset = dataset.cast_column("file_name", Audio(sampling_rate=16000))
```

## Applications

This dataset can be used for:

- 🎯 Training audio classification models for Tajweed error detection
- 📱 Building Quran recitation assessment applications
- 🔬 Research in Arabic speech processing
- 📚 Educational tools for learning proper Quran recitation
- 🤖 Developing AI-assisted Quran tutoring systems

## Error Types

The dataset includes various Tajweed errors including:
- Errors in Qalqalah (قلقلة) - echoing/bouncing sounds
- Errors in letter pronunciation
- Errors in elongation (Madd)
- And other Tajweed rule violations

## License

This dataset is released under the [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/) license.
