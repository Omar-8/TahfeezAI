# Handoff: train the s150 student on this Windows GPU PC

You are continuing Tahfeez AI's distillation milestone. Another Claude session, on a Linux laptop
without a GPU, prepared and tested everything in this kit. Your job here is training only. The
trained student goes back to the laptop for export, quantization and the benchmark.

## Rules (from the user)
- Train **s150** only. Do not start s100 until the user has reviewed s150's benchmark.
- Do not change the loss, the 43-class output, the teacher, or the benchmark exclusion
  (`benchmark_ayahs.json`: 417 ayahs never trained on, for any reciter).
- Label every result **EXPERIMENTAL / NOT YET CLEARED FOR DISTRIBUTION**: the training audio's
  recording rights are not cleared.
- Before the long run, report the throughput test to the user: GPU, VRAM, batch, seconds/step,
  estimated duration. Get their go-ahead.

## Steps (PowerShell, in this folder)
1. **Setup:** `.\setup.ps1`. Needs Python 3.12 (`py -3.12`) and an NVIDIA driver. It prints the GPU,
   its VRAM and whether it supports bf16.
   - Training uses bf16. On a GPU without it (older than RTX 30-series / Ampere), change
     `distill_student.py` to fp16 autocast with `torch.cuda.amp.GradScaler`, and tell the user.
2. **Data:** `.\.venv\Scripts\python.exe distill_student.py prepare data --hours 150`
   - Downloads ~150 h from `obadx/muaalem-annotated-v3` (all reciters) into `data\`, about 17 GB.
     It takes a while; it logs one line per reciter collection. If it is interrupted, delete `data\`
     and rerun.
3. **Throughput test:** `.\.venv\Scripts\python.exe distill_student.py bench s150 data --max-audio 320`
   - Prints one JSON line (GPU, VRAM, peak VRAM, sec/step, estimated hours for 10k–40k steps).
   - On out-of-memory, retry with `--max-audio 160`, then `80`. Use the largest value that fits,
     with headroom.
   - Report this to the user.
4. **Train** (after the user agrees), in its own window so it outlives this session:
   ```
   Start-Process powershell -ArgumentList '-NoExit','-Command','.\.venv\Scripts\python.exe distill_student.py train s150 data runs\s150 --steps 30000 --max-audio 320 --resume *> train_s150.out'
   ```
   - Use the `--max-audio` value from step 3.
   - Checkpoints are saved every 1000 steps (`runs\s150\checkpoint.pt`). After any interruption
     (reboot, crash), run the same command again: `--resume` continues from the last checkpoint.
   - Monitor with `Get-Content runs\s150\train.log -Tail 20`. Lines `step N kl … ctc …` come every
     50 steps; `VAL step N ema kl(T=1) … ctc …` every 2000. Validation KL should fall steadily;
     report it to the user now and then.
   - Turn off Windows sleep for the duration
     (`powercfg /change standby-timeout-ac 0`).
5. **When it prints `done runs\s150`,** the files to send back to the laptop are:
   - `runs\s150\student.pt` (~650 MB, the smoothed EMA weights)
   - `runs\s150\config.json`
   - `runs\s150\run.json`
   - `runs\s150\train.log`

   Not `checkpoint.pt` (2.6 GB, only needed to resume).

## Defaults and why
- Loss: KL(teacher‖student) at temperature 1 on every frame's full 43-class distribution, plus
  0.1 × CTC against the dataset's ground-truth phonemes. The app's verifier reads probability
  margins, so the student must copy the whole distribution, not just the top class.
- AdamW, learning rate 5e-4, warm-up then cosine decay, EMA 0.999, bf16, batches capped by total
  audio seconds.
