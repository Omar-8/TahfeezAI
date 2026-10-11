---
dataset_info:
  features:
  - name: audio
    dtype: audio
  - name: Surah
    dtype: string
  - name: Aya
    dtype: string
  - name: duration_ms
    dtype: int64
  - name: create_date
    dtype: string
  - name: golden
    dtype: bool
  - name: final_label
    dtype: string
  - name: reciter_id
    dtype: string
  - name: reciter_country
    dtype: string
  - name: reciter_gender
    dtype: string
  - name: reciter_age
    dtype: string
  - name: reciter_qiraah
    dtype: string
  - name: judgments_num
    dtype: int64
  - name: annotation_metadata
    dtype: string
  splits:
  - name: train
    num_bytes: 1290351809.656
    num_examples: 6828
  download_size: 1258070687
  dataset_size: 1290351809.656
configs:
- config_name: default
  data_files:
  - split: train
    path: data/train-*
task_categories:
- automatic-speech-recognition
- audio-classification
language:
- ar
tags:
- Crowdsourcing
- Quranic recitation
- Non-Arabic Speakers
pretty_name: Quranic Audio Dataset - Crowdsourced and Labeled Recitation from Non-Arabic Speakers
---

# Dataset Card for Quranic Audio Dataset : Crowdsourced and Labeled Recitation from Non-Arabic Speakers

## Dataset Summary

We explore the possibility of crowdsourcing a carefully annotated Quranic dataset, on top of which AI models can be built to simplify the learning process.
In particular, we use the volunteer-based crowdsourcing genre and implement a crowdsourcing API to gather audio assets.
We developed a crowdsourcing platform called Quran Voice for annotating the gathered audio assets.
As a result, we have collected around 7000 Quranic recitations from a pool of 1287 participants across more than 11 non-Arabic countries, and we have annotated 1166 recitations from the dataset in six categories.
We have achieved a crowd accuracy of 0.77, an inter-rater agreement of 0.63 between the annotators, and 0.89 between the labels assigned by the algorithm and the expert judgments.

## How to use
The dataset can be downloaded using the `load_dataset` function from `datasets` library.

```python
!pip install datasets
```

```python
from datasets import load_dataset

quranic_dataset = load_dataset("RetaSy/quranic_audio_dataset")

print(quranic_dataset)
```

## Dataset Structure

### Data Instances
```python
{
  'audio': {
      'path': '0058a4f7-6a3a-4665-b43b-d6f67fd14dbf.wav',
      'array': array([0.00000000e+00, 0.00000000e+00, 3.05175781e-05, ...,9.15527344e-05, 0.00000000e+00, 1.83105469e-04]),
      'sampling_rate': 16000
  },
  'Surah': 'Al-Faatihah',
  'Aya': 'أَعُوذُ بِاللَّهِ مِنَ الشَّيْطَانِ الرَّجِيْمِ',
  'duration_ms': 3520,
  'create_date': '2023-03-15T19:57:35.027430+03:00',
  'golden': False,
  'final_label': 'in_correct',
  'reciter_id': 'ef1ada15-e225-4155-a81c-fc461d940a6d',
  'reciter_country': 'AT',
  'reciter_gender': 'female',
  'reciter_age': 'Unknown',
  'reciter_qiraah': 'hafs',
  'judgments_num': 3,
  'annotation_metadata': '{
          "label_1": "in_correct",
          "annotator1_id": "1",
          "annotator1_SCT": "257",
          "annotator1_MCC": "0.87",
          "annotator1_ACC": "0.92",
          "annotator1_F1": "0.91",
          "label_2": "correct",
          "annotator2_id": "10",
          "annotator2_SCT": "21",
          "annotator2_MCC": "0.52",
          "annotator2_ACC": "0.57",
          "annotator2_F1": "0.55",
          "label_3": "in_correct",
          "annotator3_id": "19",
          "annotator3_SCT": "12",
          "annotator3_MCC": "0.75",
          "annotator3_ACC": "0.83",
          "annotator3_F1": "0.78"
  }'
}
```

### Data Fields

`audio` (`dict`): A dictionary containing the path to the downloaded audio file, the decoded audio array, and the sampling rate.

`Surah` (`string`): The chapter of the Quran from which the recited verse (Aya) is taken.

`Aya` (`string`): The specific verse within a Surah (chapter) of the Quran that is being recited.

`duration_ms` (`int64`): The duration of the audio recording in milliseconds.

`create_date` (`string`): The date and time when the audio recording was created.

`golden` (`bool`): The audio sample is labeled by experts or via crowdsourcing. If the value is true, the audio sample is considered golden, meaning it has been labeled by experts. If the value is false, the sample has been labeled via crowdsourcing.

`final_label` (`string`): The consensus label assigned to the audio sample. This label indicates the agreed-upon classification of the recitation based on the annotations provided. The final label is determined either through a majority vote among crowd-sourced annotators or by expert annotators for golden samples. The possible values for this field are:
 
  * correct: When the pronunciation is correct with the diacritics, regardless of the rules of Tajweed.
  * in_correct: When the pronunciation is incorrect with the diacritics, regardless of the rules of Tajweed.
  * not_related_quran: When the content of the audio clip is incomprehensible or contains words that have nothing to do with the Quran or is empty, this choice should be selected.
  * not_match_aya: When the audio clip contains words related to the Quran, but not the given verse, this choice should be selected.
  * multiple_aya: When a reciter reads several verses, this choice should be selected regardless of whether the reading is correct or not.
  * in_complete: When the reciter reads the verse without completing it, or the verse is not completed for some reason, this choice should be selected.

`reciter_id` (`string`): A unique identifier for the individual reciting the Quranic verse in the audio sample.

`reciter_country` (`string`): The country of origin of the reciter who performed the Quranic recitation in the audio sample.

`reciter_gender` (`string`): The gender of the reciter who performed the Quranic recitation in the audio sample.

`reciter_qiraah` (`string`): The qiraah (recitation style) used by the reciter in performing the Quranic recitation in the audio sample.

`judgments_num` (`int64`): the number of judgments or annotations provided for each audio sample in the dataset.

`annotation_metadata` (`string`): The metadata related to the annotations provided for each audio sample in the dataset. Each annotation consists of several key-value pairs:

  * label_X: The assigned label for the X-th annotator, indicating the classification or judgment made by the annotator (e.g., "correct" or "in_correct").
  * annotatorX_id: The unique identifier of the X-th annotator who provided the judgment.
  * annotatorX_SCT: The number of solved control tasks by the X-th annotator, which assess the annotator's performance on predefined control tasks.
  * annotatorX_MCC: The Matthew's Correlation Coefficient (MCC) score of the X-th annotator, measuring the quality of the annotator's classifications.
  * annotatorX_ACC: The accuracy (ACC) score of the X-th annotator, representing the proportion of correct classifications made by the annotator.
  * annotatorX_F1: The F1 score of the X-th annotator, which is a harmonic mean of precision and recall, indicating the balance between true positives and false positives.

  This detailed metadata provides insights into the annotation process, the performance of individual annotators, and the quality of the annotations assigned to each audio sample.

### Citation Information

```
@inproceedings{quran_audio_dataset:2024,
  author      = {Raghad Salameh, Mohamad Al Mdfaa, Nursultan Askarbekuly, Manuel Mazzara},
  title       = {Quranic Audio Dataset: Crowdsourced and Labeled Recitation from Non-Arabic Speakers},
  year        = 2024,
  eprint      = {2405.02675},
  eprinttype  = {arxiv},
  eprintclass = {cs.SD},
  url         = {https://arxiv.org/abs/2405.02675},
  language    = {english}
}
```