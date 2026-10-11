---
dataset_info:
  features:
  - name: audio
    dtype: audio
  - name: separate_tide
    dtype: int64
  - name: the_tight_noon
    dtype: float64
  - name: concealment
    dtype: int64
  - name: target
    dtype: int64
  - name: age
    dtype: int64
  - name: gender
    dtype: int64
  - name: id
    dtype: string
  - name: original_id
    dtype: string
  splits:
  - name: train
    num_bytes: 893938024.455
    num_examples: 1505
  download_size: 783834887
  dataset_size: 893938024.455
configs:
- config_name: default
  data_files:
  - split: train
    path: data/train-*
license: mit
task_categories:
- automatic-speech-recognition
language:
- ar
tags:
- quarn
- Quran
- qur'an
- Qur'an
- tqjweed
- Tajweed
size_categories:
- 1K<n<10K
---


# Q-dat

qdat dataset was introudced in [this paper](https://www.researchgate.net/publication/350785609_QDAT_A_data_set_for_Reciting_the_Quran) cleaned and downsampled to 16000 HZ with the following specs:
* Downsampled to 16000 HZ
* Fixed mislabeling for `origianl_id`: `s18`
* Fixed typos in the metadata as

```bash
Duplicate Items
{'file_name': 's11_6.wav', 'separate_tide': 0, 'the_tight_noon': 0, 'concealment': 0, 'target': 0, 'age': 18, 'gender': 0, 'id': '147feec0'}
{'file_name': 's11_6.wav', 'separate_tide': 0, 'the_tight_noon': 0, 'concealment': 0, 'target': 0, 'age': 18, 'gender': 0, 'id': '7ab6497e'}
----------------------------------------
{'file_name': 's19_5.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 0, 'target': 0, 'age': 40, 'gender': 0, 'id': '451ae942'}
{'file_name': 's19_5.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 48, 'gender': 0, 'id': '6a49073c'}
----------------------------------------
{'file_name': 's19_6.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 0, 'target': 0, 'age': 40, 'gender': 0, 'id': 'ceb358d8'}
{'file_name': 's19_6.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 48, 'gender': 0, 'id': '5921d4bb'}
----------------------------------------
{'file_name': 's99_9.wav', 'separate_tide': 0, 'the_tight_noon': 0, 'concealment': 0, 'target': 0, 'age': 30, 'gender': 0, 'id': '4ab77d4c'}
{'file_name': 's99_9.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 52, 'gender': 0, 'id': '4d2a3a78'}
----------------------------------------
{'file_name': 's90_3.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 62, 'gender': 1, 'id': 'cb1e5d56'}
{'file_name': 's90_3.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 40, 'gender': 0, 'id': '63c048dd'}
----------------------------------------
{'file_name': 's90_4.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 62, 'gender': 1, 'id': 'e9c6d83f'}
{'file_name': 's90_4.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 40, 'gender': 0, 'id': 'c9b1c607'}
----------------------------------------
{'file_name': 's123_4.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 50, 'gender': 0, 'id': 'e61bdb74'}
{'file_name': 's123_4.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 50, 'gender': 0, 'id': '7c80926d'}
----------------------------------------
{'file_name': 's135_1.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 48, 'gender': 0, 'id': '4a69a4e3'}
{'file_name': 's135_1.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 48, 'gender': 0, 'id': 'a2d6ec43'}
----------------------------------------
{'file_name': 's140_6.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 28, 'gender': 0, 'id': '0cb9a56b'}
{'file_name': 's140_6.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 28, 'gender': 0, 'id': 'a0db8625'}
----------------------------------------
{'file_name': 's143_4.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 42, 'gender': 0, 'id': '4f6552b1'}
{'file_name': 's143_4.wav', 'separate_tide': 1, 'the_tight_noon': 1, 'concealment': 1, 'target': 1, 'age': 42, 'gender': 0, 'id': '0b611045'}
----------------------------------------
```

## Important Notes
* the staset is compsed of reciting the verse: (قالوا لا علم لنا إلا ما علمتنا إنك أنت العليم الحكيم) only
* the number of reciters are are 160
* every reciter has recorded same verse with same way from 9 to 10 times
* every `original_id` starting with `s_x_y` where `x` is the reciter id and `y` is the index of the recitation. You may considerd them repeated !


## Dataset Features:
* audio
* `separate_tide` (المد المنفصل): 0 no madd, 1 has madd
* `the_tight_noon` (النون المشددة): 1 has and 0 hasn't
* `concealment` (إخفاء النون الساكنة) 1 has and 0 hasn't
* `target`: I did not understand it
* `age`: the age of the rectier
* `gender`: the gender of the reciter: 0 (male) and 1 (female)
* `original_id`: the filename introduced by qdat
* `id`: hash id for every item (by my)
