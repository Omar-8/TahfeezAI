---
dataset_info:
- config_name: moshaf_0.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3334598028.242
    num_examples: 9133
  download_size: 3230445287
  dataset_size: 3334598028.242
- config_name: moshaf_0.1
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 4698286022.972
    num_examples: 10764
  download_size: 4591995504
  dataset_size: 4698286022.972
- config_name: moshaf_0.2
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 5753284123.625
    num_examples: 9971
  download_size: 5634459149
  dataset_size: 5753284123.625
- config_name: moshaf_0.3
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 4340074379.292
    num_examples: 12604
  download_size: 4243397460
  dataset_size: 4340074379.292
- config_name: moshaf_1.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3327053389.686
    num_examples: 10939
  download_size: 3265981122
  dataset_size: 3327053389.686
- config_name: moshaf_11.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 2819112722.899
    num_examples: 10363
  download_size: 2770216689
  dataset_size: 2819112722.899
- config_name: moshaf_12.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3905543470.24
    num_examples: 9880
  download_size: 3840493442
  dataset_size: 3905543470.24
- config_name: moshaf_13.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3968684345.498
    num_examples: 9377
  download_size: 3907411764
  dataset_size: 3968684345.498
- config_name: moshaf_19.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3524833364.694
    num_examples: 11278
  download_size: 3473021134
  dataset_size: 3524833364.694
- config_name: moshaf_2.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 5935832969.308
    num_examples: 9942
  download_size: 5785050169
  dataset_size: 5935832969.308
- config_name: moshaf_2.1
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3513665968.962
    num_examples: 10394
  download_size: 3453234151
  dataset_size: 3513665968.962
- config_name: moshaf_22.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3293023188.836
    num_examples: 10332
  download_size: 3240629273
  dataset_size: 3293023188.836
- config_name: moshaf_24.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3338168759.764
    num_examples: 9868
  download_size: 3284506586
  dataset_size: 3338168759.764
- config_name: moshaf_25.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 2002309548.75
    num_examples: 7922
  download_size: 1954736641
  dataset_size: 2002309548.75
- config_name: moshaf_26.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3562459519.245
    num_examples: 11565
  download_size: 3501891646
  dataset_size: 3562459519.245
- config_name: moshaf_26.1
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3824376881.05
    num_examples: 11850
  download_size: 3769482568
  dataset_size: 3824376881.05
- config_name: moshaf_27.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3285597216.162
    num_examples: 11213
  download_size: 3225566078
  dataset_size: 3285597216.162
- config_name: moshaf_28.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3631369883.52
    num_examples: 10535
  download_size: 3580668939
  dataset_size: 3631369883.52
- config_name: moshaf_29.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3255064179.253
    num_examples: 11061
  download_size: 3203273156
  dataset_size: 3255064179.253
- config_name: moshaf_3.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 2956352899.056
    num_examples: 10444
  download_size: 2892648129
  dataset_size: 2956352899.056
- config_name: moshaf_30.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3411667064.376
    num_examples: 11312
  download_size: 3363071389
  dataset_size: 3411667064.376
- config_name: moshaf_4.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3408899302.75
    num_examples: 10994
  download_size: 3356357774
  dataset_size: 3408899302.75
- config_name: moshaf_5.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3281721346.268
    num_examples: 11482
  download_size: 3223256916
  dataset_size: 3281721346.268
- config_name: moshaf_6.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 4594515399.19
    num_examples: 12435
  download_size: 4537815533
  dataset_size: 4594515399.19
- config_name: moshaf_7.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3308220283.718
    num_examples: 9907
  download_size: 3260489368
  dataset_size: 3308220283.718
- config_name: moshaf_8.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3610473602.09
    num_examples: 10330
  download_size: 3530114354
  dataset_size: 3610473602.09
- config_name: moshaf_9.0
  features:
  - name: audio
    dtype:
      audio:
        sampling_rate: 16000
  - name: segment_index
    dtype: string
  - name: tarteel_transcript
    sequence: string
  - name: moshaf_id
    dtype: string
  - name: moshaf_name
    dtype: string
  - name: reciter_id
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: reciter_english_name
    dtype: string
  - name: sura_or_aya_index
    dtype: string
  - name: index_type
    dtype: string
  - name: sample_rate
    dtype: int32
  - name: duration_seconds
    dtype: float32
  - name: timestamp_seconds
    sequence: float32
  - name: imlaey
    dtype: string
  - name: uthmani
    dtype: string
  - name: has_quran
    dtype: bool
  - name: has_istiaatha
    dtype: bool
  - name: has_bismillah
    dtype: bool
  - name: has_sadaka
    dtype: bool
  - name: start_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: end_span
    struct:
    - name: sura_idx
      dtype: int32
    - name: aya_idx
      dtype: int32
    - name: imlaey
      dtype: int32
    - name: uthmani
      dtype: int32
  - name: match_ratio
    dtype: float32
  - name: phonemes
    dtype: string
  - name: sifat
    list:
    - name: ghonna
      dtype: string
    - name: hams_or_jahr
      dtype: string
    - name: istitala
      dtype: string
    - name: itbaq
      dtype: string
    - name: phonemes
      dtype: string
    - name: qalqla
      dtype: string
    - name: safeer
      dtype: string
    - name: shidda_or_rakhawa
      dtype: string
    - name: tafashie
      dtype: string
    - name: tafkheem_or_taqeeq
      dtype: string
    - name: tikraar
      dtype: string
  splits:
  - name: train
    num_bytes: 3272346962.466
    num_examples: 10642
  download_size: 3221006114
  dataset_size: 3272346962.466
- config_name: moshaf_metadata
  features:
  - name: comments
    dtype: string
  - name: total_size_mb
    dtype: float32
  - name: path
    dtype: string
  - name: madd_monfasel_len
    dtype: int32
  - name: irkab_maana
    dtype: string
  - name: yaa_ataan
    dtype: string
  - name: madd_yaa_alayn_alharfy
    dtype: int32
  - name: reciter_id
    dtype: int32
  - name: name
    dtype: string
  - name: rewaya
    dtype: string
  - name: sakt_marqdena
    dtype: string
  - name: almusaytirun
    dtype: string
  - name: sakt_iwaja
    dtype: string
  - name: is_downloaded
    dtype: bool
  - name: madd_aared_len
    dtype: int32
  - name: takbeer
    dtype: string
  - name: raa_yasr
    dtype: string
  - name: madd_mottasel_waqf
    dtype: int32
  - name: reciter_arabic_name
    dtype: string
  - name: yabsut
    dtype: string
  - name: between_anfal_and_tawba
    dtype: string
  - name: tasheel_or_madd
    dtype: string
  - name: bastah
    dtype: string
  - name: bimusaytir
    dtype: string
  - name: start_with_ism
    dtype: string
  - name: publisher
    dtype: string
  - name: sakt_bal_ran
    dtype: string
  - name: sakt_man_raq
    dtype: string
  - name: madd_alleen_len
    dtype: int32
  - name: segmented_by
    dtype: string
  - name: idgham_nakhluqkum
    dtype: string
  - name: noon_tamnna
    dtype: string
  - name: recitation_speed
    dtype: string
  - name: sources
    sequence: string
  - name: specific_sources
    list:
    - name: sura_or_aya_index
      dtype: string
    - name: url
      dtype: string
  - name: yalhath_dhalik
    dtype: string
  - name: harakat_daaf
    dtype: string
  - name: raa_misr
    dtype: string
  - name: raa_nudhur
    dtype: string
  - name: is_complete
    dtype: bool
  - name: reciter_english_name
    dtype: string
  - name: alif_salasila
    dtype: string
  - name: raa_firq
    dtype: string
  - name: is_annotated
    dtype: bool
  - name: noon_and_yaseen
    dtype: string
  - name: missing_recitations
    sequence: string
  - name: meem_aal_imran
    dtype: string
  - name: raa_alqitr
    dtype: string
  - name: sakt_maleeyah
    dtype: string
  - name: alias_start_sec
    dtype: float32
  - name: ghonna_lam_and_raa
    dtype: string
  - name: madd_mottasel_len
    dtype: int32
  - name: saken_before_hamz
    dtype: string
  - name: num_recitations
    dtype: int32
  - name: id
    dtype: string
  - name: total_duraion_minutes
    dtype: float32
  - name: meem_mokhfah
    dtype: string
  splits:
  - name: train
    num_bytes: 45008
    num_examples: 27
  download_size: 31424
  dataset_size: 45008
- config_name: reciters_metadata
  features:
  - name: arabic_name
    dtype: string
  - name: moshaf_set_ids
    sequence: string
  - name: english_name
    dtype: string
  - name: country_code
    dtype: string
  - name: id
    dtype: int32
  splits:
  - name: train
    num_bytes: 1689
    num_examples: 22
  download_size: 3647
  dataset_size: 1689
configs:
- config_name: moshaf_0.0
  data_files:
  - split: train
    path: moshaf_0.0/train-*
- config_name: moshaf_0.1
  data_files:
  - split: train
    path: moshaf_0.1/train-*
- config_name: moshaf_0.2
  data_files:
  - split: train
    path: moshaf_0.2/train-*
- config_name: moshaf_0.3
  data_files:
  - split: train
    path: moshaf_0.3/train-*
- config_name: moshaf_1.0
  data_files:
  - split: train
    path: moshaf_1.0/train-*
- config_name: moshaf_11.0
  data_files:
  - split: train
    path: moshaf_11.0/train-*
- config_name: moshaf_12.0
  data_files:
  - split: train
    path: moshaf_12.0/train-*
- config_name: moshaf_13.0
  data_files:
  - split: train
    path: moshaf_13.0/train-*
- config_name: moshaf_19.0
  data_files:
  - split: train
    path: moshaf_19.0/train-*
- config_name: moshaf_2.0
  data_files:
  - split: train
    path: moshaf_2.0/train-*
- config_name: moshaf_2.1
  data_files:
  - split: train
    path: moshaf_2.1/train-*
- config_name: moshaf_22.0
  data_files:
  - split: train
    path: moshaf_22.0/train-*
- config_name: moshaf_24.0
  data_files:
  - split: train
    path: moshaf_24.0/train-*
- config_name: moshaf_25.0
  data_files:
  - split: train
    path: moshaf_25.0/train-*
- config_name: moshaf_26.0
  data_files:
  - split: train
    path: moshaf_26.0/train-*
- config_name: moshaf_26.1
  data_files:
  - split: train
    path: moshaf_26.1/train-*
- config_name: moshaf_27.0
  data_files:
  - split: train
    path: moshaf_27.0/train-*
- config_name: moshaf_28.0
  data_files:
  - split: train
    path: moshaf_28.0/train-*
- config_name: moshaf_29.0
  data_files:
  - split: train
    path: moshaf_29.0/train-*
- config_name: moshaf_3.0
  data_files:
  - split: train
    path: moshaf_3.0/train-*
- config_name: moshaf_30.0
  data_files:
  - split: train
    path: moshaf_30.0/train-*
- config_name: moshaf_4.0
  data_files:
  - split: train
    path: moshaf_4.0/train-*
- config_name: moshaf_5.0
  data_files:
  - split: train
    path: moshaf_5.0/train-*
- config_name: moshaf_6.0
  data_files:
  - split: train
    path: moshaf_6.0/train-*
- config_name: moshaf_7.0
  data_files:
  - split: train
    path: moshaf_7.0/train-*
- config_name: moshaf_8.0
  data_files:
  - split: train
    path: moshaf_8.0/train-*
- config_name: moshaf_9.0
  data_files:
  - split: train
    path: moshaf_9.0/train-*
- config_name: moshaf_metadata
  data_files:
  - split: train
    path: moshaf_metadata/train-*
- config_name: reciters_metadata
  data_files:
  - split: train
    path: reciters_metadata/train-*
license: mit
language:
- ar
tags:
- Quran
- Qur'an
size_categories:
- 100K<n<1M
---


# قاعدة بيانات المعلم القرآنية 

هذه ال dataset هي جزء من مشروع الملم الرقرآني: [quran-muaalem](https://github.com/obadx/quran-muaalem) وهي تهدف لكشف أخاطاء التجويد عن طريق رسم صوتي يصف كل قواعد التجويد وصفات الحروف: [quran-trainscript](https://github.com/obadx/quran-transcript)

## وصف  قاعدة بيانات العلم

مصاحف مجمعمة من القراء المتقنين لبناء نماذج ذكاء اصطناعي لخدمة القرآن الكريم. أنظر [هنا](https://github.com/obadx/prepare-quran-dataset) لأكواد بناء قاعدة التلاوات القرآنية

![stats](./stats.png)

![reciters](./reciter.png)



## البيانات الوصفية للمصاحف

```python
ds = load_dataset('obadx/muaalem-annotated-v3', name='moshaf_metadata')['train']

```


### وصف أوجه حفص

|Attribute Name|Arabic Name|Values|Default Value|More Info|
|-|-|-|-|-|
|rewaya|الرواية|- `hafs` (`حفص`)<br>||The type of the quran Rewaya.|
|recitation_speed|سرعة التلاوة|- `mujawad` (`مجود`)<br>- `above_murattal` (`فويق المرتل`)<br>- `murattal` (`مرتل`)<br>- `hadr` (`حدر`)<br>|`murattal` (`مرتل`)|The recitation speed sorted from slowest to the fastest سرعة التلاوة مرتبة من الأبطأ إلي الأسرع|
|takbeer|التكبير|- `no_takbeer` (`لا تكبير`)<br>- `beginning_of_sharh` (`التكبير من أول الشرح لأول الناس`)<br>- `end_of_doha` (`التكبير من آخر الضحى لآخر الناس`)<br>- `general_takbeer` (`التكبير أول كل سورة إلا التوبة`)<br>|`no_takbeer` (`لا تكبير`)|The ways to add takbeer (الله أكبر) after Istiaatha (استعاذة) and between end of the surah and beginning of the surah. `no_takbeer`: "لا تكبير" — No Takbeer (No proclamation of greatness, i.e., there is no Takbeer recitation) `beginning_of_sharh`: "التكبير من أول الشرح لأول الناس" — Takbeer from the beginning of Surah Ash-Sharh to the beginning of Surah An-Nas `end_of_dohaf`: "التكبير من آخر الضحى لآخر الناس" — Takbeer from the end of Surah Ad-Duha to the end of Surah An-Nas `general_takbeer`: "التكبير أول كل سورة إلا التوبة" — Takbeer at the beginning of every Surah except Surah At-Tawbah|
|madd_monfasel_len|مد المنفصل|- `2`<br>- `3`<br>- `4`<br>- `5`<br>|| The length of Mad Al Monfasel "مد النفصل" for Hafs Rewaya.|
|madd_mottasel_len|مقدار المد المتصل|- `4`<br>- `5`<br>- `6`<br>|| The length of Mad Al Motasel "مد المتصل" for Hafs.|
|madd_mottasel_waqf|مقدار المد المتصل وقفا|- `4`<br>- `5`<br>- `6`<br>|| The length of Madd Almotasel at pause for Hafs.. Example "السماء".|
|madd_aared_len|مقدار المد العارض|- `2`<br>- `4`<br>- `6`<br>|| The length of Mad Al Aared "مد العارض للسكون".|
|madd_alleen_len|مقدار مد اللين|- `2`<br>- `4`<br>- `6`<br>|`None`|The length of the Madd al-Leen when stopping at the end of a word (for a sakin waw or ya preceded by a letter with a fatha) should be less than or equal to the length of Madd al-'Arid (the temporary stretch due to stopping). **Default Value is equal to `madd_aared_len`**. مقدرا مع اللين عن القوف (للواو الساكنة والياء الساكنة وقبلها حرف مفتوح) ويجب أن يكون مقدار مد اللين أقل من أو يساوي مع العارض|
|ghonna_lam_and_raa|غنة اللام و الراء|- `ghonna` (`غنة`)<br>- `no_ghonna` (`لا غنة`)<br>|`no_ghonna` (`لا غنة`)|The ghonna for merging (Idghaam) noon with Lam and Raa for Hafs.|
|meem_aal_imran|ميم آل عمران في قوله تعالى: {الم الله} وصلا|- `waqf` (`وقف`)<br>- `wasl_2` (`فتح الميم ومدها حركتين`)<br>- `wasl_6` (`فتح الميم ومدها ستة حركات`)<br>|`waqf` (`وقف`)|The ways to recite the word meem Aal Imran (الم الله) at connected recitation. `waqf`: Pause with a prolonged madd (elongation) of 6 harakat (beats). `wasl_2` Pronounce "meem" with fathah (a short "a" sound) and stretch it for 2 harakat. `wasl_6` Pronounce "meem" with fathah and stretch it for 6 harakat.|
|madd_yaa_alayn_alharfy|مقدار   المد اللازم الحرفي للعين|- `2`<br>- `4`<br>- `6`<br>|`6`| The length of Lzem Harfy of Yaa in letter Al-Ayen Madd "المد الحرفي اللازم لحرف العين" in surar: Maryam "مريم", AlShura "الشورى".|
|saken_before_hamz|الساكن قبل الهمز|- `tahqeek` (`تحقيق`)<br>- `general_sakt` (`سكت عام`)<br>- `local_sakt` (`سكت خاص`)<br>|`tahqeek` (`تحقيق`)|The ways of Hafs for saken before hamz. "The letter with sukoon before the hamzah (ء)".And it has three forms: full articulation (`tahqeeq`), general pause (`general_sakt`), and specific pause (`local_skat`).|
|sakt_iwaja|السكت عند عوجا في الكهف|- `sakt` (`سكت`)<br>- `waqf` (`وقف`)<br>- `idraj` (`إدراج`)<br>|`waqf` (`وقف`)|The ways to recite the word "عوجا" (Iwaja). `sakt` means slight pause. `idraj` means not `sakt`. `waqf`:  means full pause, so we can not determine weither the reciter uses `sakt` or `idraj` (no sakt).|
|sakt_marqdena|السكت عند مرقدنا  في يس|- `sakt` (`سكت`)<br>- `waqf` (`وقف`)<br>- `idraj` (`إدراج`)<br>|`waqf` (`وقف`)|The ways to recite the word "مرقدنا" (Marqadena) in Surat Yassen. `sakt` means slight pause. `idraj` means not `sakt`. `waqf`:  means full pause, so we can not determine weither the reciter uses `sakt` or `idraj` (no sakt).|
|sakt_man_raq|السكت عند  من راق في القيامة|- `sakt` (`سكت`)<br>- `waqf` (`وقف`)<br>- `idraj` (`إدراج`)<br>|`sakt` (`سكت`)|The ways to recite the word "من راق" (Man Raq) in Surat Al Qiyama. `sakt` means slight pause. `idraj` means not `sakt`. `waqf`:  means full pause, so we can not determine weither the reciter uses `sakt` or `idraj` (no sakt).|
|sakt_bal_ran|السكت عند  بل ران في  المطففين|- `sakt` (`سكت`)<br>- `waqf` (`وقف`)<br>- `idraj` (`إدراج`)<br>|`sakt` (`سكت`)|The ways to recite the word "بل ران" (Bal Ran) in Surat Al Motaffin. `sakt` means slight pause. `idraj` means not `sakt`. `waqf`:  means full pause, so we can not determine weither the reciter uses `sakt` or `idraj` (no sakt).|
|sakt_maleeyah|وجه  قوله تعالى {ماليه هلك} بالحاقة|- `sakt` (`سكت`)<br>- `waqf` (`وقف`)<br>- `idgham` (`إدغام`)<br>|`waqf` (`وقف`)|The ways to recite the word {ماليه هلك} in Surah Al-Ahqaf. `sakt` means slight pause. `idgham` Assimilation of the letter 'Ha' (ه) into the letter 'Ha' (ه) with complete assimilation.`waqf`:  means full pause, so we can not determine weither the reciter uses `sakt` or `idgham`.|
|between_anfal_and_tawba|وجه بين الأنفال والتوبة|- `waqf` (`وقف`)<br>- `sakt` (`سكت`)<br>- `wasl` (`وصل`)<br>|`waqf` (`وقف`)|The ways to recite end of Surah Al-Anfal and beginning of Surah At-Tawbah.|
|noon_and_yaseen|الإدغام والإظهار في النون عند الواو من قوله تعالى: {يس والقرآن}و {ن والقلم}|- `izhar` (`إظهار`)<br>- `idgham` (`إدغام`)<br>|`izhar` (`إظهار`)|Weither to merge noon of both: {يس} and {ن} with (و) "`idgham`" or not "`izhar`".|
|yaa_ataan| إثبات الياء وحذفها وقفا في قوله تعالى {آتان} بالنمل|- `wasl` (`وصل`)<br>- `hadhf` (`حذف`)<br>- `ithbat` (`إثبات`)<br>|`wasl` (`وصل`)|The affirmation and omission of the letter 'Yaa' in the pause of the verse {آتاني} in Surah An-Naml.`wasl`: means connected recitation without pasuding as (آتانيَ).`hadhf`: means deletion of letter (ي) at puase so recited as (آتان).`ithbat`: means confirmation reciting letter (ي) at puase as (آتاني).|
|start_with_ism|وجه البدأ بكلمة {الاسم} في سورة الحجرات|- `wasl` (`وصل`)<br>- `lism` (`لسم`)<br>- `alism` (`ألسم`)<br>|`wasl` (`وصل`)|The ruling on starting with the word {الاسم} in Surah Al-Hujurat.`lism` Recited as (لسم) at the beginning. `alism` Recited as (ألسم). ath the beginning`wasl`: means completing recitaion without paussing as normal, So Reciting is as (بئس لسم).|
|yabsut|السين والصاد في قوله تعالى: {والله يقبض ويبسط} بالبقرة|- `seen` (`سين`)<br>- `saad` (`صاد`)<br>|`seen` (`سين`)|The ruling on pronouncing `seen` (س) or `saad` (ص) in the verse {والله يقبض ويبسط} in Surah Al-Baqarah.|
|bastah|السين والصاد في قوله تعالى:  {وزادكم في الخلق بسطة} بالأعراف|- `seen` (`سين`)<br>- `saad` (`صاد`)<br>|`seen` (`سين`)|The ruling on pronouncing `seen` (س) or `saad` (ص ) in the verse {وزادكم في الخلق بسطة} in Surah Al-A'raf.|
|almusaytirun|السين والصاد في قوله تعالى {أم هم المصيطرون} بالطور|- `seen` (`سين`)<br>- `saad` (`صاد`)<br>|`saad` (`صاد`)|The pronunciation of `seen` (س) or `saad` (ص ) in the verse {أم هم المصيطرون} in Surah At-Tur.|
|bimusaytir|السين والصاد في قوله تعالى:  {لست عليهم بمصيطر} بالغاشية|- `seen` (`سين`)<br>- `saad` (`صاد`)<br>|`saad` (`صاد`)|The pronunciation of `seen` (س) or `saad` (ص ) in the verse {لست عليهم بمصيطر} in Surah Al-Ghashiyah.|
|tasheel_or_madd|همزة الوصل في قوله تعالى: {آلذكرين} بموضعي الأنعام و{آلآن} موضعي يونس و{آلله} بيونس والنمل|- `tasheel` (`تسهيل`)<br>- `madd` (`مد`)<br>|`madd` (`مد`)| Tasheel of Madd "وجع التسهيل أو المد" for 6 words in The Holy Quran: "ءالذكرين", "ءالله", "ءائن".|
|yalhath_dhalik|الإدغام وعدمه في قوله تعالى: {يلهث ذلك} بالأعراف|- `izhar` (`إظهار`)<br>- `idgham` (`إدغام`)<br>- `waqf` (`وقف`)<br>|`idgham` (`إدغام`)|The assimilation (`idgham`) and non-assimilation (`izhar`) in the verse {يلهث ذلك} in Surah Al-A'raf. `waqf`: means the rectier has paused on (يلهث)|
|irkab_maana|الإدغام والإظهار في قوله تعالى: {اركب معنا} بهود|- `izhar` (`إظهار`)<br>- `idgham` (`إدغام`)<br>- `waqf` (`وقف`)<br>|`idgham` (`إدغام`)|The assimilation and clear pronunciation in the verse {اركب معنا} in Surah Hud.This refers to the recitation rules concerning whether the letter "Noon" (ن) is assimilated into the following letter or pronounced clearly when reciting this specific verse. `waqf`: means the rectier has paused on (اركب)|
|noon_tamnna| الإشمام والروم (الاختلاس) في قوله تعالى {لا تأمنا على يوسف}|- `ishmam` (`إشمام`)<br>- `rawm` (`روم`)<br>|`ishmam` (`إشمام`)|The nasalization (`ishmam`) or the slight drawing (`rawm`) in the verse {لا تأمنا على يوسف}|
|harakat_daaf|حركة الضاد (فتح أو ضم) في قوله تعالى {ضعف} بالروم|- `fath` (`فتح`)<br>- `dam` (`ضم`)<br>|`fath` (`فتح`)|The vowel movement of the letter 'Dhad' (ض) (whether with `fath` or `dam`) in the word {ضعف} in Surah Ar-Rum.|
|alif_salasila|إثبات الألف وحذفها وقفا في قوله تعالى: {سلاسلا} بسورة الإنسان|- `hadhf` (`حذف`)<br>- `ithbat` (`إثبات`)<br>- `wasl` (`وصل`)<br>|`wasl` (`وصل`)|Affirmation and omission of the 'Alif' when pausing in the verse {سلاسلا} in Surah Al-Insan.This refers to the recitation rule regarding whether the final "Alif" in the word "سلاسلا" is pronounced (affirmed) or omitted when pausing (waqf) at this word during recitation in the specific verse from Surah Al-Insan. `hadhf`: means to remove alif (ا) during puase as (سلاسل) `ithbat`: means to recite alif (ا) during puase as (سلاسلا) `wasl` means completing the recitation as normal without pausing, so recite it as (سلاسلَ وأغلالا)|
|idgham_nakhluqkum|إدغام القاف في الكاف إدغاما ناقصا أو كاملا {نخلقكم} بالمرسلات|- `idgham_kamil` (`إدغام كامل`)<br>- `idgham_naqis` (`إدغام ناقص`)<br>|`idgham_kamil` (`إدغام كامل`)|Assimilation of the letter 'Qaf' into the letter 'Kaf,' whether incomplete (`idgham_naqis`) or complete (`idgham_kamil`), in the verse {نخلقكم} in Surah Al-Mursalat.|
|raa_firq|التفخيم والترقيق في راء {فرق} في الشعراء وصلا|- `waqf` (`وقف`)<br>- `tafkheem` (`تفخيم`)<br>- `tarqeeq` (`ترقيق`)<br>|`tafkheem` (`تفخيم`)|Emphasis and softening of the letter 'Ra' in the word {فرق} in Surah Ash-Shu'ara' when connected (wasl).This refers to the recitation rules concerning whether the letter "Ra" (ر) in the word "فرق"  is pronounced with emphasis (`tafkheem`) or softening (`tarqeeq`) when reciting the specific verse from Surah Ash-Shu'ara' in connected speech. `waqf`: means pasuing so we only have one way (tafkheem of Raa)|
|raa_alqitr|التفخيم والترقيق في راء {القطر} في سبأ وقفا|- `wasl` (`وصل`)<br>- `tafkheem` (`تفخيم`)<br>- `tarqeeq` (`ترقيق`)<br>|`wasl` (`وصل`)|Emphasis and softening of the letter 'Ra' in the word {القطر} in Surah Saba' when pausing (waqf).This refers to the recitation rules regarding whether the letter "Ra" (ر) in the word "القطر" is pronounced with emphasis (`tafkheem`) or softening (`tarqeeq`) when pausing at this word in Surah Saba'. `wasl`: means not pasuing so we only have one way (tarqeeq of Raa)|
|raa_misr|التفخيم والترقيق في راء {مصر} في يونس وموضعي يوسف والزخرف  وقفا|- `wasl` (`وصل`)<br>- `tafkheem` (`تفخيم`)<br>- `tarqeeq` (`ترقيق`)<br>|`wasl` (`وصل`)|Emphasis and softening of the letter 'Ra' in the word {مصر} in Surah Yunus, and in the locations of Surah Yusuf and Surah Az-Zukhruf when pausing (waqf).This refers to the recitation rules regarding whether the letter "Ra" (ر) in the word "مصر" is pronounced with emphasis (`tafkheem`) or softening (`tarqeeq`) at the specific pauses in these Surahs. `wasl`: means not pasuing so we only have one way (tafkheem of Raa)|
|raa_nudhur|التفخيم والترقيق  في راء {نذر} بالقمر وقفا|- `wasl` (`وصل`)<br>- `tafkheem` (`تفخيم`)<br>- `tarqeeq` (`ترقيق`)<br>|`tafkheem` (`تفخيم`)|Emphasis and softening of the letter 'Ra' in the word {نذر} in Surah Al-Qamar when pausing (waqf).This refers to the recitation rules regarding whether the letter "Ra" (ر) in the word "نذر" is pronounced with emphasis (`tafkheem`) or softening (`tarqeeq`) when pausing at this word in Surah Al-Qamar. `wasl`: means not pasuing so we only have one way (tarqeeq of Raa)|
|raa_yasr|التفخيم والترقيق في راء {يسر} بالفجر و{أن أسر} بطه والشعراء و{فأسر} بهود والحجر والدخان  وقفا|- `wasl` (`وصل`)<br>- `tafkheem` (`تفخيم`)<br>- `tarqeeq` (`ترقيق`)<br>|`tarqeeq` (`ترقيق`)|Emphasis and softening of the letter 'Ra' in the word {يسر} in Surah Al-Fajr when pausing (waqf).This refers to the recitation rules regarding whether the letter "Ra" (ر) in the word "يسر" is pronounced with emphasis (`tafkheem`) or softening (`tarqeeq`) when pausing at this word in Surah Al-Fajr. `wasl`: means not pasuing so we only have one way (tarqeeq of Raa)|
|meem_mokhfah|هل الميم مخفاة أو مدغمة|- `meem` (`ميم`)<br>- `ikhfaa` (`إخفاء`)<br>|`ikhfaa` (`إخفاء`)|This is not a **standard** Hafs way but a disagreement between **scholars** in our century on how to **pronounce** **Ikhfa** for meem. Some **scholars** do full merging (`إدغام`) and the others open the **lips** a little bit (`إخفاء`). We did not want to add this, but some of the best reciters disagree about this.|



## البيانات الوصفية للقراء

```python
ds = load_dataset('obadx/muaalem-annotated-v3', name='reciters_metadata')['train']
```



## المصحاف

للتسهيل على الباحثن تحميل البيانات قمنا بتقسيمها على هيئة مصاحف. واسم كل مصحف بال `id` في `moshaf_metadata`.

```python
moshaf_id = "0.0"
ds = load_dataset('obadx/muaalem-annotated-v3', name=f"moshaf_{moshaf_id}", split='train')
```

### هيكل وميزات مجموعة البيانات الصوتية للقرآن الكريم

تتكون كل عينة في مجموعة البيانات من المقاطع التالية:

#### 🎵 البيانات الصوتية
- **audio**: الملف الصوتي (تنسيق Audio)
  - معدل العينة: 16000 هرتز
  - قناة واحدة (Mono)
  - مع فك الترميز (Decode)

#### 🔖 معلومات التعريف
- **segment_index**: معرف فريد للمقطع (نصي)
- **moshaf_id**: معرّف المصحف
- **moshaf_name**: اسم المصحف
- **reciter_id**: معرّف القارئ (رقم صحيح)
- **reciter_arabic_name**: اسم القارئ بالعربية
- **reciter_english_name**: اسم القارئ بالإنجليزية

#### 📖 معلومات النص المقروء
- **sura_or_aya_index**: رقم السورة أو الآية
- **index_type**: نوع الفهرس (سورة أو آية)
- **tarteel_transcript**: النص المقروء (سلسلة نصية)

#### ⏱️ معلومات زمنية
- **sample_rate**: معدل العينة (عدد صحيح)
- **duration_seconds**: مدة المقطع بالثواني (رقم عشري)
- **timestamp_seconds**: الطوابع الزمنية للمقطع (مصفوفة أرقام)

#### 📜 نصوص القرآن بأنواعها
- **imlaey**: النص الإملائي
- **uthmani**: النص العثماني

#### 🕌 معلومات إضافية عن التلاوة
- **has_quran**: هل يحتوي على قرآن؟ (قيمة منطقية)
- **has_istiaatha**: هل يحتوي على استعاذة؟ (قيمة منطقية)
- **has_bismillah**: هل يحتوي على بسملة؟ (قيمة منطقية)
- **has_sadaka**: هل يحتوي على صدقة؟ (قيمة منطقية)

#### 🔍 نطاق التلاوة
- **start_span**: بداية النطاق
  - `sura_idx`: رقم السورة
  - `aya_idx`: رقم الآية
  - `imlaey`: الفهرس الإملائي
  - `uthmani`: الفهرس العثماني

- **end_span**: نهاية النطاق
  - (بنفس حقول start_span)

#### 📊 مقاييس الجودة
- **match_ratio**: نسبة التطابق (رقم عشري)

#### 🔤 الرسم الصوتي للقرآن
قمنا باستخراج الحروف الصوتية للقرآن باستخدام: [quran-transcript](https://github.com/obadx/quran-transcript)

- **phonemes**: الوحدات الصوتية (نصي)
- **sifat**: صفات التلاوة (قائمة من القواميس) وتشمل:
  - `ghonna`: الغنّة
  - `hams_or_jahr`: الهمس أو الجهر
  - `istitala`: الاستطالة
  - `itbaq`: الإطباق
  - `phonemes`: الوحدات الصوتية
  - `qalqla`: القلقلة
  - `safeer`: الصفير
  - `shidda_or_rakhawa`: الشدة أو الرخاوة
  - `tafashie`: التضخي
  - `tafkheem_or_taqeeq`: التفخيم أو الترقيق
  - `tikraar`: التكرار

### إحصاءات

| Moshaf ID | Hours         | Length |
|-----------|---------------|--------|
| 0.0       | 28.47721296   | 9133   |
| 0.1       | 40.31257093   | 10764  |
| 0.2       | 49.46541671   | 9971   |
| 0.3       | 37.18758118   | 12604  |
| 1.0       | 28.40784367   | 10939  |
| 2.0       | 51.04665234   | 9942   |
| 2.1       | 30.02847051   | 10394  |
| 3.0       | 25.19377593   | 10444  |
| 4.0       | 29.12333379   | 10994  |
| 5.0       | 28.01777693   | 11482  |
| 6.0       | 39.38568468   | 12435  |
| 7.0       | 28.25627201   | 9907   |
| 8.0       | 30.85935158   | 10330  |
| 9.0       | 27.95178738   | 10642  |
| 11.0      | 24.00685052   | 10363  |
| 12.0      | 33.42429862   | 9880   |
| 13.0      | 33.99108879   | 9377   |
| 19.0      | 30.11410843   | 11278  |
| 22.0      | 28.10947704   | 10332  |
| 24.0      | 28.51243509   | 9868   |
| 25.0      | 16.92910042   | 7922   |
| 26.0      | 30.44461112   | 11565  |
| 26.1      | 32.71190443   | 11850  |
| 27.0      | 28.05097968   | 11213  |
| 28.0      | 31.05318768   | 10535  |
| 29.0      | 27.78900316   | 11061  |
| 30.0      | 29.14366461   | 11312  |
| **Total** | **847.9944402** | **286537** |


![audio_lens](./histogram_all_lengths.png)




